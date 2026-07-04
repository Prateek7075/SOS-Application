<?php

use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\EmergencyContactController;
use App\Http\Controllers\Api\V1\SosController;
use App\Http\Controllers\Api\V1\UserProfileController;

Route::get('/test', function () {
    return response()->json([
        'success' => true,
        'message' => 'SOS backend API is working',
    ]);
});

Route::prefix('v1')->group(function () {

    // Firebase protected routes
    Route::middleware('firebase.auth')->group(function () {
        Route::post('/auth/sync-user', [AuthController::class, 'syncUser']);
        Route::get('/users/me', [AuthController::class, 'me']);

        // Emergency Contacts Routes
        Route::get('/emergency-contacts', [EmergencyContactController::class, 'index']);
        Route::post('/emergency-contacts', [EmergencyContactController::class, 'store']);
        Route::delete('/emergency-contacts/{id}', [EmergencyContactController::class, 'destroy']);

        //SOS Routes
        Route::post('/sos/start', [SosController::class, 'start']);
        Route::post('/sos/{id}/cancel', [SosController::class, 'cancel']);
        Route::get('/sos/history', [SosController::class, 'history']);

        //Profile Routes
        Route::get('/user-profile', [UserProfileController::class, 'show']);
        Route::put('/user-profile', [UserProfileController::class, 'update']);

        //Offline Sync Route
        Route::post('/sos/offline-sync', [SosController::class, 'offlineSync']);
    });

    // SOS Location Route (public because foreground services provide it, making it private will break that)
    Route::post('/sos/{id}/location', [SosController::class, 'location']);


    // Public Tracking Route
    Route::get('/public/track/{trackingToken}', [SosController::class, 'publicTrack']);
});
