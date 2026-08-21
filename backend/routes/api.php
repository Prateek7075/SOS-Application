<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\EmergencyContactController;
use App\Http\Controllers\Api\V1\PhoneAuthController;
use App\Http\Controllers\Api\V1\SosController;
use App\Http\Controllers\Api\V1\UserProfileController;
use Illuminate\Support\Facades\Route;

Route::get('/test', function () {
    return response()->json([
        'success' => true,
        'message' => 'SOS backend API is working',
    ]);
});

Route::prefix('v1')->group(function () {

    Route::middleware('auth:sanctum')->group(function () {
        Route::get('/users/me', [AuthController::class, 'me']);

        // Emergency Contacts Routes
        Route::get('/emergency-contacts', [EmergencyContactController::class, 'index']);
        Route::post('/emergency-contacts', [EmergencyContactController::class, 'store']);
        Route::delete('/emergency-contacts/{id}', [EmergencyContactController::class, 'destroy']);

        // SOS Routes
        Route::post('/sos/start', [SosController::class, 'start']);
        Route::post('/sos/{id}/cancel', [SosController::class, 'cancel']);
        Route::get('/sos/history', [SosController::class, 'history']);
        Route::get('/sos/active', [SosController::class, 'active']);

        // Profile Routes
        Route::get('/user-profile', [UserProfileController::class, 'show']);
        Route::put('/user-profile', [UserProfileController::class, 'update']);

        // Offline Sync Route
        Route::post('/sos/offline-sync', [SosController::class, 'offlineSync']);

        Route::post('/auth/logout', [PhoneAuthController::class, 'logout']);
    });

    Route::post('/auth/request-otp', [PhoneAuthController::class, 'requestOtp'])->middleware('throttle:otp-request');

    Route::post('/auth/verify-otp', [PhoneAuthController::class, 'verifyOtp'])->middleware('throttle:otp-verify');

    Route::post('/auth/register', [PhoneAuthController::class, 'register'])->middleware('throttle:otp-register');

    // SOS Location Route (public because foreground services provide it, making it private will break that)
    Route::post('/sos/{id}/location', [SosController::class, 'location']);

    // Public Tracking Route
    Route::get('/public/track/{trackingToken}', [SosController::class, 'publicTrack']);
});
