package com.example.mobile

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "sos_sms_channel"
    private val routeExtraName = "route"

    private var currentFlutterEngine: FlutterEngine? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        currentFlutterEngine = flutterEngine

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "sendSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")

                    if (phoneNumber.isNullOrBlank()) {
                        result.error("INVALID_PHONE", "Phone number is empty", null)
                        return@setMethodCallHandler
                    }

                    if (message.isNullOrBlank()) {
                        result.error("INVALID_MESSAGE", "SMS message is empty", null)
                        return@setMethodCallHandler
                    }

                    if (
                        checkSelfPermission(Manifest.permission.SEND_SMS)
                        != PackageManager.PERMISSION_GRANTED
                    ) {
                        result.error(
                            "PERMISSION_DENIED",
                            "SEND_SMS permission not granted",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val smsManager: SmsManager =
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                applicationContext.getSystemService(SmsManager::class.java)
                            } else {
                                @Suppress("DEPRECATION")
                                SmsManager.getDefault()
                            }

                        val messageParts = smsManager.divideMessage(message)

                        if (messageParts.size > 1) {
                            smsManager.sendMultipartTextMessage(
                                phoneNumber,
                                null,
                                messageParts,
                                null,
                                null
                            )
                        } else {
                            smsManager.sendTextMessage(
                                phoneNumber,
                                null,
                                message,
                                null,
                                null
                            )
                        }

                        result.success(true)
                    } catch (error: Exception) {
                        result.error("SEND_FAILED", error.message, null)
                    }
                }

                "startForegroundLocationService" -> {
                    val sosEventId = call.argument<Int>("sosEventId")
                    val trackingToken = call.argument<String>("trackingToken")
                    val apiBaseUrl = call.argument<String>("apiBaseUrl")

                    if (sosEventId == null || sosEventId <= 0) {
                        result.error(
                            "INVALID_SOS_ID",
                            "SOS event ID is invalid",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    if (trackingToken.isNullOrBlank()) {
                        result.error(
                            "INVALID_TRACKING_TOKEN",
                            "SOS tracking token is empty",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    if (apiBaseUrl.isNullOrBlank()) {
                        result.error(
                            "INVALID_API_URL",
                            "API base URL is empty",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val serviceIntent = Intent(
                            this,
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
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }

                        result.success(true)
                    } catch (error: Exception) {
                        result.error(
                            "SERVICE_START_FAILED",
                            error.message,
                            null
                        )
                    }
                }

                "stopForegroundLocationService" -> {
                    try {
                        val serviceIntent = Intent(
                            this,
                            SosLocationForegroundService::class.java
                        ).apply {
                            action = SosLocationForegroundService.ACTION_STOP
                        }

                        startService(serviceIntent)

                        result.success(true)
                    } catch (error: Exception) {
                        result.error(
                            "SERVICE_STOP_FAILED",
                            error.message,
                            null
                        )
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun getInitialRoute(): String {
        return intent?.getStringExtra("route") ?: "/"
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)

        setIntent(intent)

        openFlutterRouteFromIntent(intent)
    }

    private fun openFlutterRouteFromIntent(intent: Intent?) {
        val route = intent?.getStringExtra("route")

        if (route.isNullOrBlank() || route == "/") {
            return
        }

        currentFlutterEngine?.navigationChannel?.pushRoute(route)
    }
}