<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    public function syncUser(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['nullable', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:30'],
        ]);

        $user = $request->user();

        if (array_key_exists('name', $validated) && $validated['name'] !== null && trim($validated['name']) !== '')
        {
                $user->name = trim($validated['name']);
        }

        if (array_key_exists('phone', $validated) && $validated['phone'] !== null && trim($validated['phone']) !== '')
        {
                $user->phone = trim($validated['phone']);
        }


        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'User synchronized successfully',
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'phone' => $user->phone,
                ],
            ],
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'success' => true,
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'phone' => $user->phone,
                ],
            ],
        ]);
    }
}
