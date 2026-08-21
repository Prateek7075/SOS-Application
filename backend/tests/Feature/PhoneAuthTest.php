<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\Auth\OTPService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Tests\TestCase;

class PhoneAuthTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'cache.stores.redis' => [
                'driver' => 'array',
            ],
        ]);
    }

    public function test_new_login_revokes_previous_device_token(): void
    {
        $user = User::create([
            'name' => 'Test User',
            'phone' => '+919876543210',
        ]);

        $otp1 = app(OTPService::class)->generate($user->phone);

        $login1 = $this->postJson('/api/v1/auth/verify-otp', [
            'phone' => $user->phone,
            'otp' => $otp1,
        ])->assertOk();

        $token1 = $login1->json('data.token');

        // Remove OTP cooldown so we can simulate another login immediately.
        Cache::store('redis')->flush();

        $otp2 = app(OTPService::class)->generate($user->phone);

        $login2 = $this->postJson('/api/v1/auth/verify-otp', [
            'phone' => $user->phone,
            'otp' => $otp2,
        ])->assertOk();

        $token2 = $login2->json('data.token');

        $this->assertDatabaseCount('personal_access_tokens', 1);

        $this->withToken($token1)
            ->getJson('/api/v1/users/me')
            ->assertUnauthorized();

        $this->withToken($token2)
            ->getJson('/api/v1/users/me')
            ->assertOk();
    }

    public function test_logout_revokes_current_token(): void
    {
        $user = User::create([
            'name' => 'Test User',
            'phone' => '+919876543210',
        ]);

        $token = $user
            ->createToken('mobile')
            ->plainTextToken;

        $this->withToken($token)
            ->postJson('/api/v1/auth/logout')
            ->assertOk()
            ->assertJson([
                'success' => true,
                'message' => 'Logged out successfully.',
            ]);

        $this->assertDatabaseCount('personal_access_tokens', 0);

        $this->app['auth']->forgetGuards();

        $this->withToken($token)
            ->getJson('/api/v1/users/me')
            ->assertUnauthorized();
    }

    public function test_otp_is_invalidated_after_five_wrong_attempts(): void
    {
        $correctOtp = app(OTPService::class)->generate('+919876543210');

        for ($attempt = 1; $attempt <= 5; $attempt++) {
            $this->postJson('/api/v1/auth/verify-otp', [
                'phone' => '9876543210',
                'otp' => '000000',
            ])->assertStatus(422);
        }

        $this->postJson('/api/v1/auth/verify-otp', [
            'phone' => '9876543210',
            'otp' => $correctOtp,
        ])->assertStatus(422);
    }

    public function test_otp_cannot_be_requested_again_during_cooldown(): void
    {
        $this->postJson('/api/v1/auth/request-otp', [
            'phone' => '9876543210',
        ])->assertOk();

        $this->postJson('/api/v1/auth/request-otp', [
            'phone' => '9876543210',
        ])
            ->assertStatus(429)
            ->assertJson([
                'success' => false,
                'message' => 'Please wait before requesting another OTP.',
            ]);
    }

    public function test_phone_cannot_request_more_than_five_otps_per_hour(): void
    {
        for ($request = 1; $request <= 5; $request++) {
            $this->postJson('/api/v1/auth/request-otp', [
                'phone' => '9876543210',
            ])->assertOk();

            $this->travel(61)->seconds();
        }

        $this->postJson('/api/v1/auth/request-otp', [
            'phone' => '9876543210',
        ])
            ->assertStatus(429)
            ->assertJson([
                'success' => false,
                'message' => 'Too many OTP requests. Please try again later.',
            ]);
    }

    public function test_otp_requests_are_rate_limited_by_ip(): void
    {
        for ($request = 1; $request <= 10; $request++) {
            $phone = '987654'.str_pad(
                (string) $request,
                4,
                '0',
                STR_PAD_LEFT
            );

            $this->postJson('/api/v1/auth/request-otp', [
                'phone' => $phone,
            ])->assertOk();
        }

        $this->postJson('/api/v1/auth/request-otp', [
            'phone' => '9876540011',
        ])->assertStatus(429);
    }

    public function test_existing_user_can_login_with_otp(): void
    {
        $user = User::create([
            'name' => 'Test User',
            'phone' => '+919876543210',
        ]);

        $otp = app(OTPService::class)->generate($user->phone);

        $response = $this->postJson('/api/v1/auth/verify-otp', [
            'phone' => '9876543210',
            'otp' => $otp,
        ]);

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
                'registration_required' => false,
                'data' => [
                    'user' => [
                        'id' => $user->id,
                        'name' => 'Test User',
                        'phone' => '+919876543210',
                    ],
                ],
            ])
            ->assertJsonStructure([
                'data' => [
                    'token',
                    'user',
                ],
            ]);

        $this->assertDatabaseCount('users', 1);
        $this->assertDatabaseCount('personal_access_tokens', 1);
    }

    public function test_user_can_request_otp(): void
    {
        $response = $this->postJson('/api/v1/auth/request-otp', [
            'phone' => '9876543210',
        ]);

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
                'message' => 'OTP sent successfully.',
            ]);
    }

    public function test_new_user_can_verify_otp_and_get_registration_token(): void
    {
        $otp = app(OTPService::class)->generate('+919876543210');

        $response = $this->postJson('/api/v1/auth/verify-otp', [
            'phone' => '9876543210',
            'otp' => $otp,
        ]);

        $response
            ->assertOk()
            ->assertJson([
                'success' => true,
                'registration_required' => true,
            ])
            ->assertJsonStructure([
                'data' => [
                    'registration_token',
                ],
            ]);

        $this->assertSame(
            64,
            strlen($response->json('data.registration_token'))
        );
    }

    public function test_new_user_can_register_with_registration_token(): void
    {
        $otp = app(OTPService::class)->generate('+919876543210');

        $verifyResponse = $this->postJson('/api/v1/auth/verify-otp', [
            'phone' => '9876543210',
            'otp' => $otp,
        ]);

        $registrationToken = $verifyResponse->json(
            'data.registration_token'
        );

        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Test User',
            'registration_token' => $registrationToken,
        ]);

        $response
            ->assertCreated()
            ->assertJson([
                'success' => true,
                'message' => 'Registration completed successfully.',
                'data' => [
                    'user' => [
                        'name' => 'Test User',
                        'phone' => '+919876543210',
                    ],
                ],
            ])
            ->assertJsonStructure([
                'data' => [
                    'token',
                    'user' => [
                        'id',
                        'name',
                        'phone',
                    ],
                ],
            ]);

        $this->assertDatabaseHas('users', [
            'name' => 'Test User',
            'phone' => '+919876543210',
        ]);
    }

    public function test_registration_token_cannot_be_reused(): void
    {
        $otp = app(OTPService::class)->generate('+919876543210');

        $verifyResponse = $this->postJson('/api/v1/auth/verify-otp', [
            'phone' => '9876543210',
            'otp' => $otp,
        ]);

        $registrationToken = $verifyResponse->json(
            'data.registration_token'
        );

        $this->postJson('/api/v1/auth/register', [
            'name' => 'Test User',
            'registration_token' => $registrationToken,
        ])->assertCreated();

        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Test User',
            'registration_token' => $registrationToken,
        ]);

        $response
            ->assertStatus(422)
            ->assertJson([
                'success' => false,
                'message' => 'Registration session expired or invalid.',
            ]);
    }
}
