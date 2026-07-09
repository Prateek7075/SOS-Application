<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

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
        'final_latitude',
        'final_longitude',
        'final_location_updated_at',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
        'cancelled_at' => 'datetime',
        'final_location_updated_at' => 'datetime',
    ];

    public function locationUpdates(): HasMany
    {
        return $this->hasMany(SosLocationUpdate::class);
    }

    public function latestLocationUpdate(): HasOne
    {
        return $this->hasOne(SosLocationUpdate::class)
            ->latestOfMany();
    }
}
