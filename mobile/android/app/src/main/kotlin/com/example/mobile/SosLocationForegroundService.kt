package com.example.mobile

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import android.os.Handler
import android.os.Looper
import java.io.BufferedReader
import java.io.InputStreamReader
import org.json.JSONArray

class SosLocationForegroundService : Service() {
    companion object {
        const val ACTION_START = "START_SOS_LOCATION_SERVICE"
        const val ACTION_STOP = "STOP_SOS_LOCATION_SERVICE"

        const val EXTRA_SOS_EVENT_ID = "sos_event_id"
        const val EXTRA_TRACKING_TOKEN = "tracking_token"
        const val EXTRA_API_BASE_URL = "api_base_url"

        private const val CHANNEL_ID = "sos_location_channel"
        private const val NOTIFICATION_ID = 7075
        private const val TAG = "SosForegroundService"

        private const val RETRY_PREFS_NAME = "native_sos_location_retry_queue"
        private const val MAX_RETRY_QUEUE_SIZE = 200
    }

    private data class LocationPayload(
        val localId: String,
        val latitude: Double,
        val longitude: Double,
        val accuracy: Double?,
        val batteryPercentage: Int?,
        val createdAt: Long,
    )

    private data class LocationPostResult(
        val success: Boolean,
        val responseCode: Int?,
        val responseBody: String,
        val errorMessage: String?,
    )

    private var sosEventId: Int = -1
    private var trackingToken: String = ""
    private var apiBaseUrl: String = ""

    private var lastLocationSentAt = 0L

    private lateinit var locationManager: LocationManager

    private val locationListener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            sendLocationToBackend(location)
        }

        override fun onProviderEnabled(provider: String) {}

        override fun onProviderDisabled(provider: String) {}

        @Deprecated("Deprecated in Java")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    }

    private fun getBatteryPercentage(): Int? {
        return try {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager

            val batteryLevel = batteryManager.getIntProperty(
                BatteryManager.BATTERY_PROPERTY_CAPACITY
            )

            if (batteryLevel in 0..100) {
                batteryLevel
            } else {
                null
            }
        } catch (error: Exception) {
            Log.e(TAG, "Failed to read battery percentage: ${error.message}")
            null
        }
    }

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopTracking()
            clearPendingLocationUpdates()
            stopSelf()
            return START_NOT_STICKY
        }

        sosEventId = intent?.getIntExtra(EXTRA_SOS_EVENT_ID, -1) ?: -1
        trackingToken = intent?.getStringExtra(EXTRA_TRACKING_TOKEN) ?: ""
        apiBaseUrl = intent?.getStringExtra(EXTRA_API_BASE_URL) ?: ""

        if (sosEventId == -1 || trackingToken.isBlank() || apiBaseUrl.isBlank()) {
            Log.e(TAG, "Invalid SOS event ID, tracking token, or API base URL")
            stopSelf()
            return START_NOT_STICKY
        }

        val notification = createNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        startTracking()

        return START_STICKY
    }

    private fun startTracking() {
        if (
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.e(TAG, "Location permission not granted")
            stopSelf()
            return
        }

        try {
            locationManager.removeUpdates(locationListener)

            val lastGpsLocation =
                locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)

            val lastNetworkLocation =
                locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)

            val bestLastLocation = lastGpsLocation ?: lastNetworkLocation

            if (bestLastLocation != null) {
                sendLocationToBackend(bestLastLocation)
            }

            locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                30000L,
                0f,
                locationListener
            )

            locationManager.requestLocationUpdates(
                LocationManager.NETWORK_PROVIDER,
                30000L,
                0f,
                locationListener
            )

            Log.d(TAG, "Foreground location tracking started")
        } catch (error: Exception) {
            Log.e(TAG, "Failed to start location tracking: ${error.message}")
        }
    }

    private fun stopTracking() {
        try {
            locationManager.removeUpdates(locationListener)
            Log.d(TAG, "Foreground location tracking stopped")
        } catch (error: Exception) {
            Log.e(TAG, "Failed to stop location tracking: ${error.message}")
        }
    }

    private fun getRetryStorageKey(): String {
        return "native_failed_sos_location_updates_$sosEventId"
    }

    private fun getRetryPrefs() =
        getSharedPreferences(RETRY_PREFS_NAME, Context.MODE_PRIVATE)

    @Synchronized
    private fun getPendingLocationUpdates(): MutableList<LocationPayload> {
        if (sosEventId == -1) {
            return mutableListOf()
        }

        val rawJson = getRetryPrefs().getString(getRetryStorageKey(), null)

        if (rawJson.isNullOrBlank()) {
            return mutableListOf()
        }

        return try {
            val jsonArray = JSONArray(rawJson)
            val updates = mutableListOf<LocationPayload>()

            for (index in 0 until jsonArray.length()) {
                val item = jsonArray.getJSONObject(index)

                updates.add(
                    LocationPayload(
                        localId = item.optString("local_id"),
                        latitude = item.optDouble("latitude"),
                        longitude = item.optDouble("longitude"),
                        accuracy = if (item.isNull("accuracy")) {
                            null
                        } else {
                            item.optDouble("accuracy")
                        },
                        batteryPercentage = if (item.isNull("battery_percentage")) {
                            null
                        } else {
                            item.optInt("battery_percentage")
                        },
                        createdAt = item.optLong("created_at"),
                    )
                )
            }

            updates.filter { update ->
                update.localId.isNotBlank() &&
                        !update.latitude.isNaN() &&
                        !update.longitude.isNaN()
            }.toMutableList()
        } catch (error: Exception) {
            Log.e(TAG, "Failed to read native retry queue: ${error.message}")
            clearPendingLocationUpdates()
            mutableListOf()
        }
    }

    @Synchronized
    private fun savePendingLocationUpdates(updates: List<LocationPayload>) {
        if (sosEventId == -1) {
            return
        }

        val jsonArray = JSONArray()

        updates.forEach { update ->
            val item = JSONObject().apply {
                put("local_id", update.localId)
                put("latitude", update.latitude)
                put("longitude", update.longitude)

                if (update.accuracy != null) {
                    put("accuracy", update.accuracy)
                } else {
                    put("accuracy", JSONObject.NULL)
                }

                if (update.batteryPercentage != null) {
                    put("battery_percentage", update.batteryPercentage)
                } else {
                    put("battery_percentage", JSONObject.NULL)
                }

                put("created_at", update.createdAt)
            }

            jsonArray.put(item)
        }

        getRetryPrefs()
            .edit()
            .putString(getRetryStorageKey(), jsonArray.toString())
            .apply()
    }

    @Synchronized
    private fun saveLocationForRetry(payload: LocationPayload) {
        val pendingUpdates = getPendingLocationUpdates()

        pendingUpdates.add(payload)

        val trimmedUpdates = if (pendingUpdates.size > MAX_RETRY_QUEUE_SIZE) {
            pendingUpdates.takeLast(MAX_RETRY_QUEUE_SIZE)
        } else {
            pendingUpdates
        }

        savePendingLocationUpdates(trimmedUpdates)

        Log.e(
            TAG,
            "Location saved in native retry queue. SOS=$sosEventId QueueSize=${trimmedUpdates.size} Lat=${payload.latitude} Lng=${payload.longitude}"
        )
    }

    @Synchronized
    private fun removePendingLocationUpdate(localId: String) {
        val pendingUpdates = getPendingLocationUpdates()

        val updatedList = pendingUpdates.filter { update ->
            update.localId != localId
        }

        savePendingLocationUpdates(updatedList)
    }

    @Synchronized
    private fun clearPendingLocationUpdates() {
        if (sosEventId == -1) {
            return
        }

        getRetryPrefs()
            .edit()
            .remove(getRetryStorageKey())
            .apply()

        Log.d(TAG, "Native retry queue cleared for SOS=$sosEventId")
    }

    private fun shouldSaveForRetry(result: LocationPostResult): Boolean {
        val responseCode = result.responseCode

        if (responseCode == null) {
            return true
        }

        return responseCode == 408 ||
                responseCode == 429 ||
                responseCode >= 500
    }

    private fun postLocationPayloadToBackend(payload: LocationPayload): LocationPostResult {
        var connection: HttpURLConnection? = null

        return try {
            val endpoint = "$apiBaseUrl/sos/$sosEventId/location"
            val url = URL(endpoint)

            connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("X-SOS-Tracking-Token", trackingToken)
            connection.doOutput = true
            connection.connectTimeout = 10000
            connection.readTimeout = 10000

            val jsonBody = JSONObject().apply {
                put("latitude", payload.latitude)
                put("longitude", payload.longitude)

                if (payload.accuracy != null) {
                    put("accuracy", payload.accuracy)
                } else {
                    put("accuracy", JSONObject.NULL)
                }

                if (payload.batteryPercentage != null) {
                    put("battery_percentage", payload.batteryPercentage)
                } else {
                    put("battery_percentage", JSONObject.NULL)
                }
            }.toString()

            OutputStreamWriter(connection.outputStream).use { writer ->
                writer.write(jsonBody)
                writer.flush()
            }

            val responseCode = connection.responseCode
            val responseBody = readResponseBody(connection)

            LocationPostResult(
                success = responseCode == 200 || responseCode == 201,
                responseCode = responseCode,
                responseBody = responseBody,
                errorMessage = null,
            )
        } catch (error: Exception) {
            LocationPostResult(
                success = false,
                responseCode = null,
                responseBody = "",
                errorMessage = error.message,
            )
        } finally {
            connection?.disconnect()
        }
    }

    private fun retryPendingLocationUpdates(): Boolean {
        val pendingUpdates = getPendingLocationUpdates()

        if (pendingUpdates.isEmpty()) {
            return true
        }

        Log.d(
            TAG,
            "Trying native retry queue. SOS=$sosEventId Pending=${pendingUpdates.size}"
        )

        for (pendingUpdate in pendingUpdates) {
            val result = postLocationPayloadToBackend(pendingUpdate)

            if (result.success) {
                removePendingLocationUpdate(pendingUpdate.localId)

                Log.d(
                    TAG,
                    "Native retry location sent. SOS=$sosEventId LocalId=${pendingUpdate.localId}"
                )

                continue
            }

            if (
                result.responseCode != null &&
                shouldStopServiceForResponseCode(result.responseCode)
            ) {
                Log.e(
                    TAG,
                    "Native retry rejected permanently. SOS=$sosEventId Response=${result.responseCode} Body=${result.responseBody}"
                )

                stopServiceBecauseBackendRejected(
                    responseCode = result.responseCode,
                    responseBody = result.responseBody,
                )

                return false
            }

            if (!shouldSaveForRetry(result)) {
                removePendingLocationUpdate(pendingUpdate.localId)

                Log.e(
                    TAG,
                    "Native retry removed non-retryable location. SOS=$sosEventId Response=${result.responseCode} Error=${result.errorMessage}"
                )

                continue
            }

            Log.e(
                TAG,
                "Native retry still failing. SOS=$sosEventId Response=${result.responseCode ?: "NO_RESPONSE"} Error=${result.errorMessage}"
            )

            return true
        }

        return true
    }
    private fun shouldStopServiceForResponseCode(responseCode: Int): Boolean {
        return responseCode == 401 ||
                responseCode == 403 ||
                responseCode == 404 ||
                responseCode == 409 ||
                responseCode == 410 ||
                responseCode == 422
    }

    private fun readResponseBody(connection: HttpURLConnection): String {
        return try {
            val stream = if (connection.responseCode in 200..299) {
                connection.inputStream
            } else {
                connection.errorStream
            }

            if (stream == null) {
                return ""
            }

            BufferedReader(InputStreamReader(stream)).use { reader ->
                reader.readText()
            }
        } catch (error: Exception) {
            "Could not read response body: ${error.message}"
        }
    }

    private fun stopServiceBecauseBackendRejected(
        responseCode: Int,
        responseBody: String,
    ) {
        val shortResponseBody = if (responseBody.length > 500) {
            responseBody.take(500)
        } else {
            responseBody
        }

        Log.e(
            TAG,
            "Stopping SOS foreground service. Backend rejected SOS=$sosEventId Response=$responseCode Body=$shortResponseBody"
        )

        Handler(Looper.getMainLooper()).post {
            clearPendingLocationUpdates()
            stopTracking()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }

            sosEventId = -1
            trackingToken = ""
            apiBaseUrl = ""

            stopSelf()
        }
    }

    private fun sendLocationToBackend(location: Location) {
        if (sosEventId == -1 || apiBaseUrl.isBlank() || trackingToken.isBlank()) {
            return
        }

        val currentTime = System.currentTimeMillis()

        if (currentTime - lastLocationSentAt < 30000L) {
            Log.d(TAG, "Duplicate location skipped")
            return
        }

        lastLocationSentAt = currentTime

        Thread {
            val shouldContinue = retryPendingLocationUpdates()

            if (!shouldContinue) {
                return@Thread
            }

            val batteryPercentage = getBatteryPercentage()

            val currentPayload = LocationPayload(
                localId = "native_failed_location_${System.currentTimeMillis()}_${System.nanoTime()}",
                latitude = location.latitude,
                longitude = location.longitude,
                accuracy = location.accuracy.toDouble(),
                batteryPercentage = batteryPercentage,
                createdAt = System.currentTimeMillis(),
            )

            val result = postLocationPayloadToBackend(currentPayload)

            if (result.success) {
                Log.d(
                    TAG,
                    "Location sent successfully. SOS=$sosEventId Response=${result.responseCode} Lat=${location.latitude} Lng=${location.longitude} Battery=${batteryPercentage ?: "N/A"}"
                )

                return@Thread
            }

            if (
                result.responseCode != null &&
                shouldStopServiceForResponseCode(result.responseCode)
            ) {
                Log.e(
                    TAG,
                    "Location update rejected. SOS=$sosEventId Response=${result.responseCode} Body=${result.responseBody}"
                )

                stopServiceBecauseBackendRejected(
                    responseCode = result.responseCode,
                    responseBody = result.responseBody,
                )

                return@Thread
            }

            if (shouldSaveForRetry(result)) {
                saveLocationForRetry(currentPayload)

                Log.e(
                    TAG,
                    "Location send failed and saved for native retry. SOS=$sosEventId Response=${result.responseCode ?: "NO_RESPONSE"} Error=${result.errorMessage}"
                )
            } else {
                Log.e(
                    TAG,
                    "Location send failed but not retryable. SOS=$sosEventId Response=${result.responseCode} Body=${result.responseBody} Error=${result.errorMessage}"
                )
            }
        }.start()
    }

    private fun createNotification(): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java)

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("SOS Active")
                .setContentText("Sharing live location in background")
                .setSmallIcon(android.R.drawable.ic_dialog_map)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("SOS Active")
                .setContentText("Sharing live location in background")
                .setSmallIcon(android.R.drawable.ic_dialog_map)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SOS Live Location",
                NotificationManager.IMPORTANCE_LOW
            )

            channel.description = "Shows that SOS live location sharing is active"

            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "App task removed. Trying to keep SOS service alive.")

        if (sosEventId != -1 && trackingToken.isNotBlank() && apiBaseUrl.isNotBlank()) {
            val restartIntent = Intent(
                applicationContext,
                SosLocationForegroundService::class.java
            ).apply {
                action = ACTION_START
                putExtra(EXTRA_SOS_EVENT_ID, sosEventId)
                putExtra(EXTRA_TRACKING_TOKEN, trackingToken)
                putExtra(EXTRA_API_BASE_URL, apiBaseUrl)
                setPackage(packageName)
            }

            val restartPendingIntent = PendingIntent.getService(
                applicationContext,
                7076,
                restartIntent,
                PendingIntent.FLAG_ONE_SHOT or
                        PendingIntent.FLAG_IMMUTABLE or
                        PendingIntent.FLAG_UPDATE_CURRENT
            )

            val alarmManager =
                getSystemService(Context.ALARM_SERVICE) as AlarmManager

            alarmManager.set(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + 1000L,
                restartPendingIntent
            )
        }

        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        stopTracking()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}