package com.example.mototalk

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.mototalk/audio"
    private var wakeLock: PowerManager.WakeLock? = null
    private var duckFocusRequest: AudioFocusRequest? = null
    @Suppress("DEPRECATION")
    private var legacyDuckListener: AudioManager.OnAudioFocusChangeListener? = null

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
                    "requestDuckFocus" -> {
                        requestDuckFocus()
                        result.success(null)
                    }
                    "abandonDuckFocus" -> {
                        abandonDuckFocus()
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
        // Speakerphone only when no BT headset — otherwise SCO owns the route.
        @Suppress("DEPRECATION")
        am.isSpeakerphoneOn = !isBluetoothHeadsetConnected()
    }

    private fun isBluetoothHeadsetConnected(): Boolean {
        val am = audioManager()
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                am.availableCommunicationDevices.any {
                    it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                        it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP
                }
            } else {
                @Suppress("DEPRECATION")
                val devices = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                devices.any {
                    it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                        it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP
                }
            }
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Voice-activity focus: ask other apps to duck (or pause) temporarily.
     * Process death clears this automatically (system guarantee).
     */
    private fun requestDuckFocus() {
        val am = audioManager()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (duckFocusRequest != null) return
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
            val request = AudioFocusRequest.Builder(
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            )
                .setAudioAttributes(attrs)
                .setAcceptsDelayedFocusGain(false)
                .setWillPauseWhenDucked(false)
                .setOnAudioFocusChangeListener { /* we are not a media player */ }
                .build()
            val result = am.requestAudioFocus(request)
            if (result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                duckFocusRequest = request
            } else {
                Log.w(TAG, "requestDuckFocus denied: $result")
            }
        } else {
            if (legacyDuckListener != null) return
            @Suppress("DEPRECATION")
            val listener = AudioManager.OnAudioFocusChangeListener { }
            legacyDuckListener = listener
            @Suppress("DEPRECATION")
            val result = am.requestAudioFocus(
                listener,
                AudioManager.STREAM_VOICE_CALL,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            )
            if (result != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                legacyDuckListener = null
                Log.w(TAG, "legacy requestDuckFocus denied: $result")
            }
        }
    }

    private fun abandonDuckFocus() {
        val am = audioManager()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            duckFocusRequest?.let {
                am.abandonAudioFocusRequest(it)
            }
            duckFocusRequest = null
        } else {
            legacyDuckListener?.let { listener ->
                @Suppress("DEPRECATION")
                am.abandonAudioFocus(listener)
            }
            legacyDuckListener = null
        }
    }

    private fun resetAudioMode() {
        abandonDuckFocus()
        val am = audioManager()
        try {
            @Suppress("DEPRECATION")
            if (am.isBluetoothScoOn) {
                @Suppress("DEPRECATION")
                am.stopBluetoothSco()
                @Suppress("DEPRECATION")
                am.isBluetoothScoOn = false
            }
        } catch (_: Exception) {
        }
        am.mode = AudioManager.MODE_NORMAL
        @Suppress("DEPRECATION")
        am.isSpeakerphoneOn = false
    }

    private fun enableBluetoothSco() {
        val am = audioManager()
        try {
            am.mode = AudioManager.MODE_IN_COMMUNICATION
            @Suppress("DEPRECATION")
            am.startBluetoothSco()
            @Suppress("DEPRECATION")
            am.isBluetoothScoOn = true
            @Suppress("DEPRECATION")
            am.isSpeakerphoneOn = false
        } catch (e: Exception) {
            // Device may not support SCO — keep communication mode anyway.
        }
    }

    private fun disableBluetoothSco() {
        val am = audioManager()
        try {
            @Suppress("DEPRECATION")
            if (am.isBluetoothScoOn) {
                @Suppress("DEPRECATION")
                am.stopBluetoothSco()
                @Suppress("DEPRECATION")
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
        abandonDuckFocus()
        releaseWakeLock()
        resetAudioMode()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "MotoTalkAudio"
    }
}
