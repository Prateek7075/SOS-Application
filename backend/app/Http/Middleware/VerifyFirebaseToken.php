<?php

namespace App\Http\Middleware;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Kreait\Firebase\Contract\Auth;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

class VerifyFirebaseToken
{
    public function __construct(
        private Auth $firebaseAuth
    ) {
    }

    public function handle(Request $request, Closure $next): Response
    {
        $idToken = $request->bearerToken();

        if (!$idToken) {
            return response()->json([
                'success' => false,
                'message' => 'Firebase ID token is required',
            ], 401);
        }

        try {
            $verifiedToken = $this->firebaseAuth->verifyIdToken($idToken);
            $claims = $verifiedToken->claims();

            $firebaseUid = $claims->get('sub');
            $email = $claims->get('email');

            if (!$email) {
                return response()->json([
                    'success' => false,
                    'message' => 'Firebase account has no email address',
                ], 422);
            }

            $user = User::query()
                ->where('firebase_uid', $firebaseUid)
                ->orWhere('email', $email)
                ->first();

            if (!$user) {
                $user = new User();
            }

            $user->fill([
                'firebase_uid' => $firebaseUid,
                'name' => $claims->get(
                    'name',
                    Str::before($email, '@')
                ),
                'email' => $email,
            ]);

            $user->save();

            $request->setUserResolver(
                static fn () => $user
            );

            return $next($request);
        } catch (Throwable $error) {
            report($error);

            return response()->json([
                'success' => false,
                'message' => 'Invalid or expired Firebase ID token',
            ], 401);
        }
    }
}
