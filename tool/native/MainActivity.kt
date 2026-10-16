package __PKG__

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "little_one/bg").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> {
                        val i = Intent(this, ListenService::class.java)
                            .putExtra("title", call.argument<String>("title"))
                            .putExtra("text", call.argument<String>("text"))
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
                        result.success(true)
                    }
                    "update" -> {
                        ListenService.update(this, call.argument<String>("title") ?: "", call.argument<String>("text") ?: "")
                        result.success(true)
                    }
                    "stop" -> {
                        stopService(Intent(this, ListenService::class.java))
                        result.success(true)
                    }
                    "battery" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        if (Build.VERSION.SDK_INT >= 23 && !pm.isIgnoringBatteryOptimizations(packageName)) {
                            startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
                        } else {
                            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                        }
                        result.success(true)
                    }
                    "speaker" -> {
                        // calls: loudspeaker on/off and "in call" audio mode
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val on = call.argument<Boolean>("on") ?: true
                        val active = call.argument<Boolean>("active") ?: true
                        am.mode = if (active) AudioManager.MODE_IN_COMMUNICATION else AudioManager.MODE_NORMAL
                        @Suppress("DEPRECATION")
                        am.isSpeakerphoneOn = active && on
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.success(false)
            }
        }
    }
}
