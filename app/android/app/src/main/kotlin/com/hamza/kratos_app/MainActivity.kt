package com.hamza.kratos_app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.hamza.kratos/focus_session"
        var instance: MainActivity? = null
    }

    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
    }

    override fun onDestroy() {
        if (instance == this) instance = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "startFocusSession", "startLiveActivity" -> {
                        val sessionId = call.argument<String>("sessionId") ?: "session_${System.currentTimeMillis()}"
                        val title = call.argument<String>("title") ?: "Focus Session"
                        val lifeArea = call.argument<String>("lifeAreaName") ?: ""
                        FocusSessionService.startService(applicationContext, sessionId, title, lifeArea)
                        result.success(true)
                    }
                    "pauseFocusSession" -> {
                        FocusSessionService.pauseService(applicationContext)
                        result.success(true)
                    }
                    "resumeFocusSession" -> {
                        FocusSessionService.resumeService(applicationContext)
                        result.success(true)
                    }
                    "stopFocusSession", "endLiveActivity" -> {
                        FocusSessionService.stopService(applicationContext)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun notifyFlutterMethod(method: String, arguments: Any? = null) {
        runOnUiThread {
            methodChannel?.invokeMethod(method, arguments)
        }
    }
}
