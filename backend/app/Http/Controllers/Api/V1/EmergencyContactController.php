<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\EmergencyContact;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class EmergencyContactController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $contacts = EmergencyContact::query()
            ->where('user_id', $user->id)
            ->latest()
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Emergency contacts loaded successfully',
            'data' => [
                'contacts' => $contacts,
            ],
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'max:30'],
            'relationship' => ['nullable', 'string', 'max:255'],
        ]);

        $contact = EmergencyContact::create([
            'user_id' => $user->id,
            'name' => $validated['name'],
            'phone' => $validated['phone'],
            'relationship' => $validated['relationship'] ?? null,
            'has_app' => false,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Emergency contact saved successfully',
            'data' => [
                'contact' => $contact,
            ],
        ], 201);
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $user = $request->user();

        $contact = EmergencyContact::query()
            ->where('id', $id)
            ->where('user_id', $user->id)
            ->firstOrFail();

        $contact->delete();

        return response()->json([
            'success' => true,
            'message' => 'Emergency contact deleted successfully',
        ]);
    }
}
