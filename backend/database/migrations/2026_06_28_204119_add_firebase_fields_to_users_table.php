<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('firebase_uid')
                ->nullable()
                ->unique()
                ->after('id');

            $table->string('phone', 30)
                ->nullable()
                ->after('email');

            $table->string('password')
                ->nullable()
                ->change();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique('users_firebase_uid_unique');
            $table->dropColumn(['firebase_uid', 'phone']);

            $table->string('password')
                ->nullable(false)
                ->change();
        });
    }
};
