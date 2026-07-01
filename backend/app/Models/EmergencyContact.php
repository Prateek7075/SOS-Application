<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class EmergencyContact extends Model
{
    protected $fillable = [
        'user_id',
        'name',
        'phone',
        'relationship',
        'has_app',
        'fcm_token',
    ];

    protected $casts = [
        'has_app' => 'boolean',
    ];
}
