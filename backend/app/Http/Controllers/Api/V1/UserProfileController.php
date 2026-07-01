<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\UserProfile;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class UserProfileController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();

        $profile = UserProfile::query()
            ->where('user_id', $user->id)
            ->first();

        return response()->json([
            'success' => true,
            'message' => 'User profile loaded successfully',
            'data' => [
                'profile' => [
                    'name' => $user->name,
                    'email' => $user->email,
                    'phone' => $user->phone,
                    'blood_group' => $profile?->blood_group,
                    'relative_name' => $profile?->relative_name,
                    'relative_phone' => $profile?->relative_phone,
                    'address' => $profile?->address,
                ],
            ],
        ]);
    }

    public function update(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'name' => ['nullable', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:30'],
            'blood_group' => ['nullable', 'string', 'max:20'],
            'relative_name' => ['nullable', 'string', 'max:255'],
            'relative_phone' => ['nullable', 'string', 'max:30'],
            'address' => ['nullable', 'string', 'max:2000'],
        ]);

        if (array_key_exists('name', $validated)) {
            $user->name = $validated['name'];
        }

        if (array_key_exists('phone', $validated)) {
            $user->phone = $validated['phone'];
        }

        $user->save();

        $profile = UserProfile::query()
            ->firstOrNew([
                'user_id' => $user->id,
            ]);

        if (array_key_exists('blood_group', $validated)) {
            $profile->blood_group = $validated['blood_group'];
        }

        if (array_key_exists('relative_name', $validated)) {
            $profile->relative_name = $validated['relative_name'];
        }

        if (array_key_exists('relative_phone', $validated)) {
            $profile->relative_phone = $validated['relative_phone'];
        }

        if (array_key_exists('address', $validated)) {
            $profile->address = $validated['address'];
        }

        $profile->save();

        return response()->json([
            'success' => true,
            'message' => 'User profile updated successfully',
            'data' => [
                'profile' => [
                    'name' => $user->name,
                    'email' => $user->email,
                    'phone' => $user->phone,
                    'blood_group' => $profile->blood_group,
                    'relative_name' => $profile->relative_name,
                    'relative_phone' => $profile->relative_phone,
                    'address' => $profile->address,
                ],
            ],
        ]);
    }
}
