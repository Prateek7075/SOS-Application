<?php

namespace App\Services\Auth;

use Illuminate\Support\Facades\Cache;
use RuntimeException;

class OTPService
{
    private const OTP_TTL_SECONDS = 300;

    private const RESEND_COOLDOWN_SECONDS = 60;

    private const REQUEST_WINDOW_SECONDS = 3600;

    private const MAX_VERIFY_ATTEMPTS = 5;

    private const MAX_REQUESTS_PER_HOUR = 5;

    private const KEY_PREFIX = 'otp:auth:';

    private function otpKey(string $phone): string
    {
        return self::KEY_PREFIX.'code:'.$phone;
    }

    private function attemptsKey(string $phone): string
    {
        return self::KEY_PREFIX.'attempts:'.$phone;
    }

    private function cooldownKey(string $phone): string
    {
        return self::KEY_PREFIX.'cooldown:'.$phone;
    }

    private function requestCountKey(string $phone): string
    {
        return self::KEY_PREFIX.'requests:'.$phone;
    }

    public function generate(string $phone): string
    {
        $cache = Cache::store('redis');

        $requestCountKey = $this->requestCountKey($phone);

        $cache->add(
            $requestCountKey,
            0,
            self::REQUEST_WINDOW_SECONDS
        );

        $requestCount = (int) $cache->get($requestCountKey, 0);

        if ($requestCount >= self::MAX_REQUESTS_PER_HOUR) {
            throw new RuntimeException(
                'Too many OTP requests. Please try again later.'
            );
        }

        $cooldownCreated = $cache->add(
            $this->cooldownKey($phone),
            true,
            self::RESEND_COOLDOWN_SECONDS
        );

        if (! $cooldownCreated) {
            throw new RuntimeException(
                'Please wait before requesting another OTP.'
            );
        }

        $otp = (string) random_int(100000, 999999);

        $hashedOtp = hash_hmac(
            'sha256',
            $otp,
            config('app.key')
        );

        $cache->put(
            $this->otpKey($phone),
            $hashedOtp,
            self::OTP_TTL_SECONDS
        );

        $cache->put(
            $this->attemptsKey($phone),
            0,
            self::OTP_TTL_SECONDS
        );

        $cache->increment($requestCountKey);

        return $otp;
    }

    public function verify(string $phone, string $otp): bool
    {
        $cache = Cache::store('redis');

        $otpKey = $this->otpKey($phone);
        $attemptsKey = $this->attemptsKey($phone);

        $storedHash = $cache->get($otpKey);

        if (! is_string($storedHash)) {
            return false;
        }

        $attempts = (int) $cache->get($attemptsKey, 0);

        if ($attempts >= self::MAX_VERIFY_ATTEMPTS) {
            $cache->forget($otpKey);
            $cache->forget($attemptsKey);

            return false;
        }

        $providedHash = hash_hmac(
            'sha256',
            $otp,
            config('app.key')
        );

        if (! hash_equals($storedHash, $providedHash)) {
            $attempts = $cache->increment($attemptsKey);

            if ($attempts >= self::MAX_VERIFY_ATTEMPTS) {
                $cache->forget($otpKey);
                $cache->forget($attemptsKey);
            }

            return false;
        }

        $cache->forget($otpKey);
        $cache->forget($attemptsKey);

        return true;
    }

    public function rollback(string $phone, string $otp): void
    {
        $cache = Cache::store('redis');

        $otpKey = $this->otpKey($phone);
        $storedHash = $cache->get($otpKey);

        if (! is_string($storedHash)) {
            return;
        }

        $generatedHash = hash_hmac(
            'sha256',
            $otp,
            config('app.key')
        );

        if (! hash_equals($storedHash, $generatedHash)) {
            return;
        }

        $cache->forget($otpKey);
        $cache->forget($this->attemptsKey($phone));
        $cache->forget($this->cooldownKey($phone));
    }
}
