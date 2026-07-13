package com.example.mobile

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

class SosRecoveryWorker(
    context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {

    companion object {
        private const val TAG = "SosRecoveryWorker"

        private const val WORK_NAME = "sos_recovery_worker"

        private const val RECOVERY_PREFS_NAME = "sos_recovery_state"
        private const val KEY_RECOVERY_ENABLED = "sos_recovery_enabled"
        private const val KEY_RECOVERY_SOS_EVENT_ID = "sos_recovery_sos_event_id"
        private const val KEY_RECOVERY_TRACKING_TOKEN = "sos_recovery_tracking_token"
        private const val KEY_RECOVERY_API_BASE_URL = "sos_recovery_api_base_url"

        private const val HEARTBEAT_PREFS_NAME = "sos_foreground_service_state"
        private const val KEY_SERVICE_HEARTBEAT_AT = "native_service_last_heartbeat_at"
        private const val KEY_ACTIVE_SOS_EVENT_ID = "native_service_active_sos_event_id"
        private const val KEY_ACTIVE_TRACKING_TOKEN = "native_service_active_tracking_token"

        private const val STALE_HEARTBEAT_THRESHOLD_MS = 90000L

        fun saveRecoveryState(
            context: Context,
            sosEventId: Int,
            trackingToken: String,
            apiBaseUrl: String
        ) {
            context
                .getSharedPreferences(
                    RECOVERY_PREFS_NAME,
                    Context.MODE_PRIVATE
                )
                .edit()
                .putBoolean(
                    KEY_RECOVERY_ENABLED,
                    true
                )
                .putInt(
                    KEY_RECOVERY_SOS_EVENT_ID,
                    sosEventId
                )
                .putString(
                    KEY_RECOVERY_TRACKING_TOKEN,
                    trackingToken
                )
                .putString(
                    KEY_RECOVERY_API_BASE_URL,
                    apiBaseUrl
                )
                .apply()

            Log.d(
                TAG,
                "SOS recovery state saved. SOS=$sosEventId"
            )
        }

        fun clearRecoveryState(context: Context) {
            context
                .getSharedPreferences(
                    RECOVERY_PREFS_NAME,
                    Context.MODE_PRIVATE
                )
                .edit()
                .clear()
                .apply()

            Log.d(TAG, "SOS recovery state cleared")
        }

        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
                .build()

            val workRequest =
                PeriodicWorkRequestBuilder<SosRecoveryWorker>(
                    15,
                    TimeUnit.MINUTES
                )
                    .setConstraints(constraints)
                    .setBackoffCriteria(
                        BackoffPolicy.EXPONENTIAL,
                        30,
                        TimeUnit.SECONDS
                    )
                    .addTag(WORK_NAME)
                    .build()

            WorkManager
                .getInstance(context.applicationContext)
                .enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.UPDATE,
                    workRequest
                )

            Log.d(TAG, "SOS recovery worker scheduled")
        }

        fun cancel(context: Context) {
            WorkManager
                .getInstance(context.applicationContext)
                .cancelUniqueWork(WORK_NAME)

            Log.d(TAG, "SOS recovery worker cancelled")
        }
    }

    override fun doWork(): Result {
        val context = applicationContext

        return try {
            val recoveryPrefs = context.getSharedPreferences(
                RECOVERY_PREFS_NAME,
                Context.MODE_PRIVATE
            )

            val isRecoveryEnabled = recoveryPrefs.getBoolean(
                KEY_RECOVERY_ENABLED,
                false
            )

            if (!isRecoveryEnabled) {
                Log.d(TAG, "Recovery skipped: recovery is disabled")
                return Result.success()
            }

            val sosEventId = recoveryPrefs.getInt(
                KEY_RECOVERY_SOS_EVENT_ID,
                -1
            )

            val trackingToken = recoveryPrefs.getString(
                KEY_RECOVERY_TRACKING_TOKEN,
                ""
            ) ?: ""

            val apiBaseUrl = recoveryPrefs.getString(
                KEY_RECOVERY_API_BASE_URL,
                ""
            ) ?: ""

            if (
                sosEventId <= 0 ||
                trackingToken.isBlank() ||
                apiBaseUrl.isBlank()
            ) {
                Log.e(
                    TAG,
                    "Recovery skipped: invalid saved SOS data"
                )

                return Result.success()
            }

            val heartbeatPrefs = context.getSharedPreferences(
                HEARTBEAT_PREFS_NAME,
                Context.MODE_PRIVATE
            )

            val lastHeartbeatAt = heartbeatPrefs.getLong(
                KEY_SERVICE_HEARTBEAT_AT,
                0L
            )

            val heartbeatSosEventId = heartbeatPrefs.getInt(
                KEY_ACTIVE_SOS_EVENT_ID,
                -1
            )

            val heartbeatTrackingToken = heartbeatPrefs.getString(
                KEY_ACTIVE_TRACKING_TOKEN,
                ""
            ) ?: ""

            val now = System.currentTimeMillis()

            val heartbeatAgeMs =
                if (lastHeartbeatAt > 0L) {
                    now - lastHeartbeatAt
                } else {
                    Long.MAX_VALUE
                }

            val isHeartbeatFreshForCurrentSos =
                lastHeartbeatAt > 0L &&
                        heartbeatAgeMs <= STALE_HEARTBEAT_THRESHOLD_MS &&
                        heartbeatSosEventId == sosEventId &&
                        heartbeatTrackingToken == trackingToken

            if (isHeartbeatFreshForCurrentSos) {
                Log.d(
                    TAG,
                    "Recovery skipped: service heartbeat is fresh. " +
                            "SOS=$sosEventId Age=${heartbeatAgeMs}ms"
                )

                return Result.success()
            }

            Log.e(
                TAG,
                "Recovery needed: service heartbeat is stale/missing. " +
                        "SOS=$sosEventId Age=${heartbeatAgeMs}ms"
            )

            restartSosForegroundService(
                context = context,
                sosEventId = sosEventId,
                trackingToken = trackingToken,
                apiBaseUrl = apiBaseUrl
            )

            Result.success()
        } catch (error: Exception) {
            Log.e(
                TAG,
                "SOS recovery worker failed: ${error.message}"
            )

            Result.success()
        }
    }

    private fun restartSosForegroundService(
        context: Context,
        sosEventId: Int,
        trackingToken: String,
        apiBaseUrl: String
    ) {
        val serviceIntent = Intent(
            context,
            SosLocationForegroundService::class.java
        ).apply {
            action = SosLocationForegroundService.ACTION_START

            putExtra(
                SosLocationForegroundService.EXTRA_SOS_EVENT_ID,
                sosEventId
            )

            putExtra(
                SosLocationForegroundService.EXTRA_TRACKING_TOKEN,
                trackingToken
            )

            putExtra(
                SosLocationForegroundService.EXTRA_API_BASE_URL,
                apiBaseUrl
            )
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }

        Log.d(
            TAG,
            "Recovery worker requested foreground service restart. SOS=$sosEventId"
        )
    }
}