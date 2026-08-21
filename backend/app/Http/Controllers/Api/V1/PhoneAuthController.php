<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\Auth\OtpSender;
use App\Services\Auth\OTPService;
use App\Services\Auth\PhoneNumberService;
use App\Services\Auth\RegistrationTokenService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;
use Throwable;

class PhoneAuthController extends Controller
{
    public function requestOtp(
        Request $request,
        PhoneNumberService $phoneNumberService,
        OTPService $otpService,
        OtpSender $otpSender,
    ): JsonResponse {
        $validated = $request->validate([
            'phone' => ['required', 'string', 'max:30'],
        ]);

        $phone = $phoneNumberService->normalize(
            $validated['phone']
        );

        if ($phone === null) {
            return response()->json([
                'success' => false,
                'message' => 'Enter a valid Indian mobile number.',
            ], 422);
        }

        try {
            $otp = $otpService->generate($phone);
        } catch (RuntimeException $exception) {
            return response()->json([
                'success' => false,
                'message' => $exception->getMessage(),
            ], 429);
        }

        try {
            $otpSender->send($phone, $otp);
        } catch (Throwable $exception) {
            $otpService->rollback($phone, $otp);

            report($exception);

            return response()->json([
                'success' => false,
                'message' => 'Unable to send OTP. Please try again.',
            ], 500);
        }

        return response()->json([
            'success' => true,
            'message' => 'OTP sent successfully.',
        ]);
    }

    public function verifyOtp(
        Request $request,
        PhoneNumberService $phoneNumberService,
        OTPService $otpService,
        RegistrationTokenService $registrationTokenService,
    ): JsonResponse {
        $validated = $request->validate([
            'phone' => ['required', 'string', 'max:30'],
            'otp' => ['required', 'string', 'digits:6'],
        ]);

        $phone = $phoneNumberService->normalize(
            $validated['phone']
        );

        if ($phone === null) {
            return response()->json([
                'success' => false,
                'message' => 'Enter a valid Indian mobile number.',
            ], 422);
        }

        if (! $otpService->verify($phone, $validated['otp'])) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid or expired OTP.',
            ], 422);
        }

        $user = User::where('phone', $phone)->first();

        if ($user !== null) {
            $user->tokens()->delete();

            $token = $user
                ->createToken('mobile')
                ->plainTextToken;

            return response()->json([
                'success' => true,
                'registration_required' => false,
                'data' => [
                    'token' => $token,
                    'user' => [
                        'id' => $user->id,
                        'name' => $user->name,
                        'phone' => $user->phone,
                    ],
                ],
            ]);
        }

        $registrationToken = $registrationTokenService->create(
            $phone
        );

        return response()->json([
            'success' => true,
            'registration_required' => true,
            'data' => [
                'registration_token' => $registrationToken,
            ],
        ]);
    }

    public function register(
        Request $request,
        RegistrationTokenService $registrationTokenService,
    ): JsonResponse {
        $validated = $request->validate([
            'name' => ['required', 'string', 'min:2', 'max:255'],
            'registration_token' => ['required', 'string', 'size:64'],
        ]);

        $phone = $registrationTokenService->consume(
            $validated['registration_token']
        );

        if ($phone === null) {
            return response()->json([
                'success' => false,
                'message' => 'Registration session expired or invalid.',
            ], 422);
        }

        try {
            $user = User::firstOrCreate(
                [
                    'phone' => $phone,
                ],
                [
                    'name' => trim($validated['name']),
                ]
            );

            $user->tokens()->delete();

            $token = $user
                ->createToken('mobile')
                ->plainTextToken;
        } catch (Throwable $exception) {
            $registrationTokenService->restore(
                $validated['registration_token'],
                $phone
            );

            report($exception);

            return response()->json([
                'success' => false,
                'message' => 'Unable to complete registration. Please try again.',
            ], 500);
        }

        return response()->json([
            'success' => true,
            'message' => 'Registration completed successfully.',
            'data' => [
                'token' => $token,
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'phone' => $user->phone,
                ],
            ],
        ], 201);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()
            ?->currentAccessToken()
            ?->delete();

        return response()->json([
            'success' => true,
            'message' => 'Logged out successfully.',
        ]);
    }
}
