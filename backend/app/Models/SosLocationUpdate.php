<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SosLocationUpdate extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'sos_event_id',
        'latitude',
        'longitude',
        'accuracy',
        'battery_percentage',
        'created_at',
    ];
}
