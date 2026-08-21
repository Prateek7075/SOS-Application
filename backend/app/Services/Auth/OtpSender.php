<?php

namespace App\Services\Auth;

interface OtpSender
{
    public function send(string $phone, string $otp): void;
}
