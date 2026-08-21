<?php

namespace App\Services\Auth;

use Illuminate\Support\Facades\Cache;

class RegistrationTokenService
{
    private const TTL_SECONDS = 600;

    private const KEY_PREFIX = 'auth:registration:';

    private function key(string $token): string
    {
        $tokenHash = hash_hmac(
            'sha256',
            $token,
            config('app.key')
        );

        return self::KEY_PREFIX.$tokenHash;
    }

    public function create(string $phone): string
    {
        $token = bin2hex(random_bytes(32));

        Cache::store('redis')->put(
            $this->key($token),
            $phone,
            self::TTL_SECONDS
        );

        return $token;
    }

    public function consume(string $token): ?string
    {
        $phone = Cache::store('redis')->pull(
            $this->key($token)
        );

        return is_string($phone) ? $phone : null;
    }

    public function restore(string $token, string $phone): void
    {
        Cache::store('redis')->put(
            $this->key($token),
            $phone,
            self::TTL_SECONDS
        );
    }
}
