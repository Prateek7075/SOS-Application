package com.example.mobile

import android.Manifest
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
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import android.app.AlarmManager
import android.os.SystemClock

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
    }

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

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopTracking()
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
                15000L,
                0f,
                locationListener
            )

            locationManager.requestLocationUpdates(
                LocationManager.NETWORK_PROVIDER,
                15000L,
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

    private fun sendLocationToBackend(location: Location) {
        if (sosEventId == -1 || apiBaseUrl.isBlank()) {
            return
        }

        val currentTime = System.currentTimeMillis()

        if (currentTime - lastLocationSentAt < 15000L) {
            Log.d(TAG, "Duplicate location skipped")
            return
        }

        lastLocationSentAt = currentTime

        Thread {
            try {
                val endpoint = "$apiBaseUrl/sos/$sosEventId/location"
                val url = URL(endpoint)

                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("X-SOS-Tracking-Token", trackingToken)
                connection.doOutput = true
                connection.connectTimeout = 10000
                connection.readTimeout = 10000

                val jsonBody = """
                    {
                      "latitude": ${location.latitude},
                      "longitude": ${location.longitude},
                      "accuracy": ${location.accuracy},
                      "battery_percentage": null
                    }
                """.trimIndent()

                val writer = OutputStreamWriter(connection.outputStream)
                writer.write(jsonBody)
                writer.flush()
                writer.close()

                val responseCode = connection.responseCode

                Log.d(
                    TAG,
                    "Location sent. SOS=$sosEventId Response=$responseCode Lat=${location.latitude} Lng=${location.longitude}"
                )

                connection.disconnect()
            } catch (error: Exception) {
                Log.e(TAG, "Failed to send location: ${error.message}")
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