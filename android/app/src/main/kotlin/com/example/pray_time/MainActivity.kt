package com.example.pray_time

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.pray_time/permissions"
    private val WIDGET_CHANNEL = "com.example.pray_time/widget"
    private val REQUEST_CODE_NOTIFICATION = 100
    
    private var widgetRefreshReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            if (ContextCompat.checkSelfPermission(
                                    this,
                                    Manifest.permission.POST_NOTIFICATIONS
                                ) == PackageManager.PERMISSION_GRANTED
                            ) {
                                result.success(true)
                            } else {
                                ActivityCompat.requestPermissions(
                                    this,
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    REQUEST_CODE_NOTIFICATION
                                )
                                result.success(false) // Will be true after user grants
                            }
                        } else {
                            result.success(true) // Not needed on Android < 13
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        
        // Widget refresh channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "refreshWidget" -> {
                        // Trigger widget cache update and refresh
                        PrayerWidgetProvider.triggerWidgetRefresh(this)
                        result.success(true)
                    }
                    "sendWidgetUpdateBroadcast" -> {
                        // Broadcast to update both widgets by triggering their onReceive handlers
                        Log.d("[MainActivity]", ">>> Sending ACTION_MANUAL_REFRESH broadcast")
                        val intentVertical = Intent("com.example.pray_time.ACTION_MANUAL_REFRESH")
                        intentVertical.setPackage(packageName)
                        sendBroadcast(intentVertical)
                        
                        Log.d("[MainActivity]", ">>> Sending ACTION_MANUAL_REFRESH_H broadcast")
                        val intentHorizontal = Intent("com.example.pray_time.ACTION_MANUAL_REFRESH_H")
                        intentHorizontal.setPackage(packageName)
                        sendBroadcast(intentHorizontal)
                        
                        Log.d("[MainActivity]", ">>> Both broadcasts sent")
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        
        // Set up broadcast receiver for widget cache refresh requests from worker
        setupWidgetRefreshReceiver(flutterEngine)
    }
    
    private fun setupWidgetRefreshReceiver(flutterEngine: FlutterEngine) {
        widgetRefreshReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "com.example.pray_time.REFRESH_WIDGET_CACHE") {
                    // Call Dart to fetch fresh prayer times
                    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
                        .invokeMethod("refreshWidget", null, object : MethodChannel.Result {
                            override fun success(result: Any?) {
                                // Dart completed the refresh
                            }
                            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                                // Error occurred in Dart
                            }
                            override fun notImplemented() {
                                // Method not implemented
                            }
                        })
                }
            }
        }
        
        val intentFilter = IntentFilter("com.example.pray_time.REFRESH_WIDGET_CACHE")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(widgetRefreshReceiver, intentFilter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(widgetRefreshReceiver, intentFilter)
        }
    }
    
    override fun onDestroy() {
        if (widgetRefreshReceiver != null) {
            try {
                unregisterReceiver(widgetRefreshReceiver)
            } catch (e: Exception) {
                // Receiver might not be registered
            }
        }
        super.onDestroy()
    }
}

