<?php

namespace App\Providers;

use App\Services\Auth\LogOtpSender;
use App\Services\Auth\OtpSender;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        if ($this->app->environment(['local', 'testing'])) {
            $this->app->bind(
                OtpSender::class,
                LogOtpSender::class
            );
        }
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        RateLimiter::for('otp-request', function (Request $request) {
            return Limit::perMinute(10)
                ->by('otp-request:'.$request->ip());
        });

        RateLimiter::for('otp-verify', function (Request $request) {
            return Limit::perMinute(30)
                ->by('otp-verify:'.$request->ip());
        });

        RateLimiter::for('otp-register', function (Request $request) {
            return Limit::perMinute(10)
                ->by('otp-register:'.$request->ip());
        });
    }
}
