<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;

use App\Models\SosEvent;
use App\Models\SosLocationUpdate;
use App\Models\UserProfile;
use App\Models\User;


use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class SosController extends Controller
{

    private const TRACKING_LINK_EXPIRY_HOURS = 24;


    public function start(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'latitude' => ['required', 'numeric'],
            'longitude' => ['required', 'numeric'],
            'network_mode' => ['required', 'string'],
        ]);

        $existingActiveSos = SosEvent::where('user_id', $user->id)
            ->where('status', 'active')
            ->latest()
            ->first();

        if ($existingActiveSos) {
            return response()->json([
                'success' => true,
                'message' => 'Existing active SOS found. Continuing active SOS.',
                'data' => [
                    'was_existing_active_sos' => true,
                    'sos_event' => $existingActiveSos,
                    'tracking_url' => url('/track/' . $existingActiveSos->tracking_token),
                ],
            ], 200);
        }

        $trackingToken = Str::random(64);

        $sosEvent = SosEvent::create([
            'user_id' => $user->id,
            'status' => 'active',
            'initial_latitude' => $validated['latitude'],
            'initial_longitude' => $validated['longitude'],
            'tracking_token' => $trackingToken,
            'network_mode' => $validated['network_mode'],
            'expires_at' => now()->addHours(self::TRACKING_LINK_EXPIRY_HOURS),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'SOS started successfully',
            'data' => [
                'was_existing_active_sos' => false,
                'sos_event' => $sosEvent,
                'tracking_url' => url('/track/' . $trackingToken),
            ],
        ], 201);
    }

    public function location(Request $request, int $id): JsonResponse
    {
        $trackingToken = $request->header('X-SOS-Tracking-Token');

        if (!$trackingToken) {
            return response()->json([
                'success' => false,
                'message' => 'SOS tracking token is required',
            ], 401);
        }

        $sosEvent = SosEvent::query()
            ->where('id', $id)
            ->where('tracking_token', $trackingToken)
            ->firstOrFail();

        if ($sosEvent->status !== 'active') {
            return response()->json([
                'success' => false,
                'message' => 'Cannot add location update because SOS is not active',
            ], 422);
        }

        $validated = $request->validate([
            'latitude' => ['required', 'numeric'],
            'longitude' => ['required', 'numeric'],
            'accuracy' => ['nullable', 'numeric'],
            'battery_percentage' => ['nullable', 'integer', 'min:0', 'max:100'],
        ]);

        $locationUpdate = SosLocationUpdate::create([
            'sos_event_id' => $sosEvent->id,
            'latitude' => $validated['latitude'],
            'longitude' => $validated['longitude'],
            'accuracy' => $validated['accuracy'] ?? null,
            'battery_percentage' => $validated['battery_percentage'] ?? null,
            'created_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Location update saved successfully',
            'data' => [
                'location_update' => $locationUpdate,
            ],
        ], 201);
    }

    public function cancel(Request $request, int $id): JsonResponse
    {
        $user = $request->user();

        $sosEvent = SosEvent::query()
            ->where('id', $id)
            ->where('user_id', $user->id)
            ->firstOrFail();

        if ($sosEvent->status !== 'active') {
            return response()->json([
                'success' => false,
                'message' => 'SOS is already not active',
            ], 422);
        }

        $sosEvent->update([
            'status' => 'cancelled',
            'cancelled_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'SOS cancelled successfully',
            'data' => [
                'sos_event' => $sosEvent,
            ],
        ]);
    }

    public function publicTrack(string $trackingToken): JsonResponse
    {
        $sosEvent = SosEvent::where('tracking_token', $trackingToken)->firstOrFail();

        if ($sosEvent->expires_at && now()->greaterThan($sosEvent->expires_at)) {
            return response()->json([
                'success' => false,
                'message' => 'Tracking link has expired',
            ], 410);
        }

        $latestLocation = $sosEvent->locationUpdates()
            ->latest('created_at')
            ->first();

        $user = null;
        $profile = null;

        if ($sosEvent->user_id) {
            $user = User::find($sosEvent->user_id);

            $profile = UserProfile::query()
                ->where('user_id', $sosEvent->user_id)
                ->first();
        }

        return response()->json([
            'success' => true,
            'data' => [
                'status' => $sosEvent->status,

                'emergency_profile' => [
                    'name' => $user?->name,
                    'phone' => $user?->phone,
                    'blood_group' => $profile?->blood_group,
                    'relative_name' => $profile?->relative_name,
                    'relative_phone' => $profile?->relative_phone,
                    'address' => $profile?->address,
                ],

                'initial_location' => [
                    'latitude' => $sosEvent->initial_latitude,
                    'longitude' => $sosEvent->initial_longitude,
                ],

                'latest_location' => $latestLocation ? [
                    'latitude' => $latestLocation->latitude,
                    'longitude' => $latestLocation->longitude,
                    'accuracy' => $latestLocation->accuracy,
                    'battery_percentage' => $latestLocation->battery_percentage,
                    'created_at' => $latestLocation->created_at,
                ] : null,

                'expires_at' => $sosEvent->expires_at,
            ],
        ]);
    }

    public function history(Request $request): JsonResponse
    {
        $user = $request->user();

        $sosEvents = SosEvent::query()
            ->where('user_id', $user->id)
            ->latest()
            ->get([
                'id',
                'status',
                'initial_latitude',
                'initial_longitude',
                'network_mode',
                'expires_at',
                'cancelled_at',
                'created_at',
            ]);

        return response()->json([
            'success' => true,
            'data' => [
                'sos_events' => $sosEvents,
            ],
        ]);
    }

    public function offlineSync(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'local_id' => ['required', 'string', 'max:255'],
            'latitude' => ['required', 'numeric'],
            'longitude' => ['required', 'numeric'],
            'battery_percentage' => ['nullable', 'integer', 'min:0', 'max:100'],
            'network_mode' => ['nullable', 'string', 'max:255'],
            'sms_sent_count' => ['nullable', 'integer', 'min:0'],
            'sms_message' => ['nullable', 'string'],
            'created_at' => ['nullable', 'date'],
        ]);

        $trackingToken = Str::random(64);

        $sosEvent = SosEvent::create([
            'user_id' => $user->id,
            'status' => 'offline_sms',
            'initial_latitude' => $validated['latitude'],
            'initial_longitude' => $validated['longitude'],
            'tracking_token' => $trackingToken,
            'network_mode' => $validated['network_mode'] ?? 'offline_sms',
            'expires_at' => now()->addHours(self::TRACKING_LINK_EXPIRY_HOURS),
            'created_at' => $validated['created_at'] ?? now(),
            'updated_at' => now(),
        ]);

        SosLocationUpdate::create([
            'sos_event_id' => $sosEvent->id,
            'latitude' => $validated['latitude'],
            'longitude' => $validated['longitude'],
            'accuracy' => null,
            'battery_percentage' => $validated['battery_percentage'] ?? null,
            'created_at' => $validated['created_at'] ?? now(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Offline SOS synced successfully',
            'data' => [
                'sos_event' => $sosEvent,
            ],
        ], 201);
    }
}
