<?php

namespace App\Services\Auth;

use Illuminate\Support\Facades\Log;

class LogOtpSender implements OtpSender
{
    public function send(string $phone, string $otp): void
    {
        Log::info('OTP generated for development', [
            'phone' => $phone,
            'otp' => $otp,
        ]);
    }
}
