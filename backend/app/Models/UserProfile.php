<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class UserProfile extends Model
{
    protected $fillable = [
        'user_id',
        'blood_group',
        'relative_name',
        'relative_phone',
        'address',
    ];
}
