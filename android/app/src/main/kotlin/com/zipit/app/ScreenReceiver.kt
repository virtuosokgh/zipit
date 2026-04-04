package com.zipit.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class ScreenReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_SCREEN_OFF) return

        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("lockscreen_enabled", false)) return
        if ((prefs.getString("lockscreen_name_0", "") ?: "").isEmpty()) return
        if (LockScreenActivity.isActive) return

        // MainActivity가 활성 상태일 때는 MainActivity에서 직접 실행하므로 여기서는 skip
        // 서비스만 실행 중일 때 (앱이 완전 백그라운드) fallback 시도
        Log.d("ZipitLock", "ScreenReceiver: SCREEN_OFF fallback attempt")
        try {
            val activityIntent = Intent(context, LockScreenActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION
            }
            context.startActivity(activityIntent)
        } catch (e: Exception) {
            Log.d("ZipitLock", "Fallback launch failed (expected on API 36): ${e.message}")
        }
    }
}
