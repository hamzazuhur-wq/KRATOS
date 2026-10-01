package com.hamza.kratos_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class FocusNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            "com.hamza.kratos.ACTION_PAUSE" -> {
                // Immediately pause native notification chronometer
                FocusSessionService.pauseService(context)
                MainActivity.instance?.notifyFlutterMethod("onNativePause")
            }
            "com.hamza.kratos.ACTION_RESUME" -> {
                // Immediately resume native notification chronometer
                FocusSessionService.resumeService(context)
                MainActivity.instance?.notifyFlutterMethod("onNativeResume")
            }
            "com.hamza.kratos.ACTION_COMPLETE" -> {
                MainActivity.instance?.notifyFlutterMethod("onNativeComplete")
                FocusSessionService.stopService(context)
            }
            "com.hamza.kratos.ACTION_STOP" -> {
                MainActivity.instance?.notifyFlutterMethod("onNativeStop")
                FocusSessionService.stopService(context)
            }
        }
    }
}
