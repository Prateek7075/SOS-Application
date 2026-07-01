<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json([
        'success' => true,
        'message' => 'SOS backend is running',
    ]);
});

Route::get('/track/{trackingToken}', function (string $trackingToken) {
    return view('track', [
        'trackingToken' => $trackingToken,
    ]);
});
