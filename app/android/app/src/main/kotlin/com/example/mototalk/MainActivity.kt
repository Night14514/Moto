package com.example.mototalk

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.mototalk/audio"
    private var audioService: AudioForegroundService? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    startAudioForegroundService()
                    result.success(null)
                }
                "stopForegroundService" -> {
                    stopAudioForegroundService()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startAudioForegroundService() {
        val intent = Intent(this, AudioForegroundService::class.java)
        startForegroundService(intent)
    }

    private fun stopAudioForegroundService() {
        val intent = Intent(this, AudioForegroundService::class.java)
        stopService(intent)
    }
}
