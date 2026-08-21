<?php

namespace App\Services\Auth;

class PhoneNumberService
{
    public function normalize(string $phone): ?string
    {
        $phone = preg_replace('/[\s-]+/', '', trim($phone));

        if (preg_match('/^\+91([6-9][0-9]{9})$/', $phone, $matches)) {
            return '+91'.$matches[1];
        }

        if (preg_match('/^91([6-9][0-9]{9})$/', $phone, $matches)) {
            return '+91'.$matches[1];
        }

        if (preg_match('/^0([6-9][0-9]{9})$/', $phone, $matches)) {
            return '+91'.$matches[1];
        }

        if (preg_match('/^([6-9][0-9]{9})$/', $phone, $matches)) {
            return '+91'.$matches[1];
        }

        return null;
    }
}
