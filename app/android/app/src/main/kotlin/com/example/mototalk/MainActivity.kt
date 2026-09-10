package com.example.mototalk

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.mototalk/audio"
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForegroundService" -> {
                        startAudioForegroundService()
                        result.success(null)
                    }
                    "stopForegroundService" -> {
                        stopAudioForegroundService()
                        result.success(null)
                    }
                    "setCommunicationMode" -> {
                        setCommunicationMode()
                        result.success(null)
                    }
                    "resetAudioMode" -> {
                        resetAudioMode()
                        result.success(null)
                    }
                    "enableBluetoothSco" -> {
                        enableBluetoothSco()
                        result.success(null)
                    }
                    "disableBluetoothSco" -> {
                        disableBluetoothSco()
                        result.success(null)
                    }
                    "acquireWakeLock" -> {
                        acquireWakeLock()
                        result.success(null)
                    }
                    "releaseWakeLock" -> {
                        releaseWakeLock()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun audioManager(): AudioManager =
        getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private fun setCommunicationMode() {
        val am = audioManager()
        am.mode = AudioManager.MODE_IN_COMMUNICATION
        // Prefer earpiece/headset path for voice; SCO handles BT HFP.
        am.isSpeakerphoneOn = true
    }

    private fun resetAudioMode() {
        val am = audioManager()
        try {
            if (am.isBluetoothScoOn) {
                am.stopBluetoothSco()
                am.isBluetoothScoOn = false
            }
        } catch (_: Exception) {
        }
        am.mode = AudioManager.MODE_NORMAL
        am.isSpeakerphoneOn = false
    }

    private fun enableBluetoothSco() {
        val am = audioManager()
        try {
            am.mode = AudioManager.MODE_IN_COMMUNICATION
            am.startBluetoothSco()
            am.isBluetoothScoOn = true
        } catch (e: Exception) {
            // Device may not support SCO — keep communication mode anyway.
        }
    }

    private fun disableBluetoothSco() {
        val am = audioManager()
        try {
            if (am.isBluetoothScoOn) {
                am.stopBluetoothSco()
                am.isBluetoothScoOn = false
            }
        } catch (_: Exception) {
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "MotoTalk:CallWakeLock"
        ).apply {
            setReferenceCounted(false)
            acquire(60 * 60 * 1000L) // 1 hour max; released on endCall
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    private fun startAudioForegroundService() {
        val intent = Intent(this, AudioForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopAudioForegroundService() {
        stopService(Intent(this, AudioForegroundService::class.java))
    }

    override fun onDestroy() {
        releaseWakeLock()
        resetAudioMode()
        super.onDestroy()
    }
}
