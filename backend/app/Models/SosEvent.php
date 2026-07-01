<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Models\SosLocationUpdate;

class SosEvent extends Model
{
    protected $fillable = [
        'user_id',
        'status',
        'initial_latitude',
        'initial_longitude',
        'tracking_token',
        'network_mode',
        'expires_at',
        'cancelled_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'cancelled_at' => 'datetime',
    ];

    public function locationUpdates()
    {
        return $this->hasMany(SosLocationUpdate::class);
    }
}
