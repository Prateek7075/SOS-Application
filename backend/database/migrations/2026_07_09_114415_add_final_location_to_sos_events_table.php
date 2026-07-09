<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sos_events', function (Blueprint $table) {
            $table->decimal('final_latitude', 10, 7)->nullable()->after('initial_longitude');
            $table->decimal('final_longitude', 10, 7)->nullable()->after('final_latitude');
            $table->timestamp('final_location_updated_at')->nullable()->after('final_longitude');
        });
    }

    public function down(): void
    {
        Schema::table('sos_events', function (Blueprint $table) {
            $table->dropColumn([
                'final_latitude',
                'final_longitude',
                'final_location_updated_at',
            ]);
        });
    }
};
