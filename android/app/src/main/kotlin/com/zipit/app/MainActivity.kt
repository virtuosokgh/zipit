package com.zipit.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.zipit.app/lockscreen"
        private const val NAV_CHANNEL = "com.zipit.app/navigation"
    }

    private var navChannel: MethodChannel? = null
    private var pendingRoute: String? = null

    // 화면 꺼질 때 앱을 뒤로 보내서 잠금화면 뒤에 안 비치게
    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_OFF) {
                val prefs = ctx.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                if (prefs.getBoolean("lockscreen_enabled", false)
                    && (prefs.getString("lockscreen_name_0", "") ?: "").isNotEmpty()
                    && !LockScreenActivity.isActive) {
                    Log.d("ZipitLock", "MainActivity: SCREEN_OFF → launching LockScreenActivity")
                    val lockIntent = Intent(ctx, LockScreenActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                Intent.FLAG_ACTIVITY_NO_ANIMATION
                    }
                    startActivity(lockIntent)
                }
                moveTaskToBack(true)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerReceiver(screenOffReceiver, IntentFilter(Intent.ACTION_SCREEN_OFF))
    }

    override fun onDestroy() {
        try { unregisterReceiver(screenOffReceiver) } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        navChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAV_CHANNEL)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableLockScreen" -> {
                        val title = call.argument<String>("title") ?: ""
                        val interest = call.argument<String>("interest") ?: ""
                        val names = call.argument<List<String>>("names") ?: emptyList()
                        val prices = call.argument<List<String>>("prices") ?: emptyList()
                        val dates = call.argument<List<String>>("dates") ?: emptyList()
                        val regionCodes = call.argument<List<String>>("regionCodes") ?: emptyList()
                        Log.d("ZipitLock", "enableLockScreen: title=$title, interest=$interest")
                        saveLockScreenData(title, interest, names, prices, dates, regionCodes)
                        try {
                            LockScreenService.start(this)
                        } catch (e: Exception) {
                            Log.e("ZipitLock", "Failed to start service", e)
                        }
                        result.success(true)
                    }
                    "updateData" -> {
                        val title = call.argument<String>("title") ?: ""
                        val interest = call.argument<String>("interest") ?: ""
                        val names = call.argument<List<String>>("names") ?: emptyList()
                        val prices = call.argument<List<String>>("prices") ?: emptyList()
                        val dates = call.argument<List<String>>("dates") ?: emptyList()
                        saveLockScreenData(title, interest, names, prices, dates)
                        // 알림 갱신 트리거
                        try { LockScreenService.start(this) } catch (_: Exception) {}
                        result.success(true)
                    }
                    "disableLockScreen" -> {
                        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                        prefs.edit().putBoolean("lockscreen_enabled", false).apply()
                        LockScreenService.stop(this)
                        result.success(true)
                    }
                    "getPendingRoute" -> {
                        val route = pendingRoute
                        pendingRoute = null
                        result.success(route)
                    }
                    else -> result.notImplemented()
                }
            }

        // 잠금화면에서 앱 열렸을 때 pending route 확인
        handleIntent(intent)

        // 잠금화면 서비스 자동 복구: enabled인데 서비스가 안 돌고 있으면 재시작
        restoreLockScreenServiceIfNeeded()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val route = intent.getStringExtra("lockscreen_route")
        if (route != null) {
            Log.d("ZipitLock", "handleIntent: route=$route")
            if (navChannel != null) {
                navChannel?.invokeMethod("navigate", route)
            } else {
                pendingRoute = route
            }
            // 사용 후 제거
            intent.removeExtra("lockscreen_route")
        }
    }

    private fun restoreLockScreenServiceIfNeeded() {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean("lockscreen_enabled", false)
        val hasData = (prefs.getString("lockscreen_name_0", "") ?: "").isNotEmpty()
        if (enabled && hasData) {
            Log.d("ZipitLock", "Restoring LockScreenService on app start")
            try {
                LockScreenService.start(this)
            } catch (e: Exception) {
                Log.e("ZipitLock", "Failed to restore service", e)
            }
        }
    }

    private fun saveLockScreenData(
        title: String,
        interest: String,
        names: List<String>,
        prices: List<String>,
        dates: List<String>,
        regionCodes: List<String> = emptyList()
    ) {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putBoolean("lockscreen_enabled", true)
            putString("lockscreen_title", title)
            putString("lockscreen_interest", interest)
            for (i in 0 until 3) {
                putString("lockscreen_name_$i", if (i < names.size) names[i] else "")
                putString("lockscreen_price_$i", if (i < prices.size) prices[i] else "")
                putString("lockscreen_date_$i", if (i < dates.size) dates[i] else "")
                putString("lockscreen_regioncode_$i", if (i < regionCodes.size) regionCodes[i] else "")
            }
            apply()
        }
    }
}
