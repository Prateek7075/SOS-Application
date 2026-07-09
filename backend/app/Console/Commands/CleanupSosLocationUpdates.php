<?php

namespace App\Console\Commands;

use App\Models\SosEvent;
use App\Models\SosLocationUpdate;
use Illuminate\Console\Command;

class CleanupSosLocationUpdates extends Command
{
    protected $signature = 'sos:cleanup-location-updates {--hours=24}';

    protected $description = 'Save final SOS location and delete old SOS location updates after SOS is cancelled or offline synced';

    public function handle(): int
    {
        $retentionHours = (int) $this->option('hours');

        if ($retentionHours < 1) {
            $retentionHours = 24;
        }

        $cutoffTime = now()->subHours($retentionHours);

        $deletedCount = 0;
        $savedFinalLocationCount = 0;

        SosEvent::query()
            ->where(function ($query) use ($cutoffTime) {
                $query->where(function ($cancelledQuery) use ($cutoffTime) {
                    $cancelledQuery
                        ->where('status', 'cancelled')
                        ->whereNotNull('cancelled_at')
                        ->where('cancelled_at', '<=', $cutoffTime);
                })
                ->orWhere(function ($offlineQuery) use ($cutoffTime) {
                    $offlineQuery
                        ->where('status', 'offline_sms')
                        ->where('created_at', '<=', $cutoffTime);
                });
            })
            ->with('latestLocationUpdate')
            ->select('id')
            ->chunkById(100, function ($sosEvents) use (&$deletedCount, &$savedFinalLocationCount) {
                $sosEventIds = $sosEvents->pluck('id');

                foreach ($sosEvents as $sosEvent) {
                    $latestLocation = $sosEvent->latestLocationUpdate;

                    if (
                        $latestLocation &&
                        $latestLocation->latitude !== null &&
                        $latestLocation->longitude !== null
                    ) {
                        $sosEvent->update([
                            'final_latitude' => $latestLocation->latitude,
                            'final_longitude' => $latestLocation->longitude,
                            'final_location_updated_at' => $latestLocation->created_at,
                        ]);

                        $savedFinalLocationCount++;
                    }
                }

                $deletedCount += SosLocationUpdate::query()
                    ->whereIn('sos_event_id', $sosEventIds)
                    ->delete();
            });

        $this->info("Saved {$savedFinalLocationCount} final SOS locations.");
        $this->info("Deleted {$deletedCount} SOS location update records.");

        return self::SUCCESS;
    }
}
