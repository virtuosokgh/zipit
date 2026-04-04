package com.zipit.app

import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

class LockScreenActivity : Activity() {

    companion object {
        @Volatile var isActive = false
    }

    private var unlockReceiver: BroadcastReceiver? = null
    private var swipeStartY = 0f
    private var swipeStartX = 0f
    private var swiping = false
    private var isDismissing = false
    private var lastDataHash = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        }

        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_lockscreen)

        // 전체화면 (onCreate에서 한 번만 - onResume 반복 호출 시 깜빡임 유발)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.let {
                it.hide(android.view.WindowInsets.Type.statusBars() or android.view.WindowInsets.Type.navigationBars())
                it.systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        }

        lastDataHash = computeDataHash()
        refreshUI()

        unlockReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                if (intent.action == Intent.ACTION_USER_PRESENT) {
                    finishAndRemoveTask()
                    overridePendingTransition(0, 0)
                }
            }
        }
        registerReceiver(
            unlockReceiver,
            IntentFilter(Intent.ACTION_USER_PRESENT),
            Context.RECEIVER_NOT_EXPORTED
        )
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        isDismissing = false
        val currentHash = computeDataHash()
        if (currentHash != lastDataHash) {
            lastDataHash = currentHash
            refreshUI()
        }
    }

    override fun onResume() {
        super.onResume()
        isActive = true
        isDismissing = false
    }

    override fun onStop() {
        super.onStop()
        isActive = false
    }

    override fun onDestroy() {
        isActive = false
        unlockReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
        unlockReceiver = null
        super.onDestroy()
    }

    // ── 스와이프 감지 ──

    override fun dispatchTouchEvent(ev: MotionEvent): Boolean {
        when (ev.action) {
            MotionEvent.ACTION_DOWN -> {
                swipeStartY = ev.rawY
                swipeStartX = ev.rawX
                swiping = false
            }
            MotionEvent.ACTION_MOVE -> {
                val dy = swipeStartY - ev.rawY
                val dx = Math.abs(ev.rawX - swipeStartX)
                if (dy > 80 && dy > dx * 1.5) swiping = true
            }
            MotionEvent.ACTION_UP -> {
                if (swiping && swipeStartY - ev.rawY > 200) {
                    dismiss(null)
                    return true
                }
                swiping = false
            }
            MotionEvent.ACTION_CANCEL -> swiping = false
        }
        return super.dispatchTouchEvent(ev)
    }

    // ── 잠금 해제 + 종료 ──

    private fun dismiss(route: String?) {
        if (isDismissing) return
        isDismissing = true

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            km.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                override fun onDismissSucceeded() {
                    if (route != null) launchMainActivity(route)
                    finishAndRemoveTask()
                    overridePendingTransition(0, 0)
                }
                override fun onDismissCancelled() {
                    if (route != null) {
                        launchMainActivity(route)
                        finishAndRemoveTask()
                        overridePendingTransition(0, 0)
                    } else {
                        isDismissing = false
                    }
                }
                override fun onDismissError() {
                    if (route != null) launchMainActivity(route)
                    finishAndRemoveTask()
                    overridePendingTransition(0, 0)
                }
            })
        } else {
            if (route != null) launchMainActivity(route)
            finishAndRemoveTask()
            overridePendingTransition(0, 0)
        }
    }

    private fun launchMainActivity(route: String) {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("lockscreen_route", route)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e("ZipitLock", "Failed to launch app", e)
        }
    }

    // ── UI ──

    private fun computeDataHash(): Int {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val sb = StringBuilder()
        sb.append(prefs.getString("lockscreen_title", "") ?: "")
        for (i in 0 until 3) {
            sb.append(prefs.getString("lockscreen_name_$i", "") ?: "")
            sb.append(prefs.getString("lockscreen_price_$i", "") ?: "")
            sb.append(prefs.getString("lockscreen_date_$i", "") ?: "")
        }
        return sb.toString().hashCode()
    }

    private fun refreshUI() {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val interest = prefs.getString("lockscreen_interest", "") ?: ""
        loadData(prefs)
        setupClickHandlers(prefs, interest)
    }

    private fun loadData(prefs: android.content.SharedPreferences) {
        val title = prefs.getString("lockscreen_title", "") ?: ""
        findViewById<TextView>(R.id.ls_title).text = title

        val rowIds = intArrayOf(R.id.ls_row_1, R.id.ls_row_2, R.id.ls_row_3)
        val nameIds = intArrayOf(R.id.ls_name_1, R.id.ls_name_2, R.id.ls_name_3)
        val priceIds = intArrayOf(R.id.ls_price_1, R.id.ls_price_2, R.id.ls_price_3)
        val dateIds = intArrayOf(R.id.ls_date_1, R.id.ls_date_2, R.id.ls_date_3)

        for (i in 0 until 3) {
            val name = prefs.getString("lockscreen_name_$i", "") ?: ""
            val price = prefs.getString("lockscreen_price_$i", "") ?: ""
            val date = prefs.getString("lockscreen_date_$i", "") ?: ""

            if (name.isNotEmpty()) {
                findViewById<LinearLayout>(rowIds[i]).visibility = View.VISIBLE
                findViewById<TextView>(nameIds[i]).text = name
                findViewById<TextView>(priceIds[i]).text = price
                findViewById<TextView>(dateIds[i]).text = date
            } else {
                findViewById<LinearLayout>(rowIds[i]).visibility = View.GONE
            }
        }
    }

    private fun setupClickHandlers(prefs: android.content.SharedPreferences, interest: String) {
        val rowIds = intArrayOf(R.id.ls_row_1, R.id.ls_row_2, R.id.ls_row_3)
        for (i in rowIds.indices) {
            val row = findViewById<LinearLayout>(rowIds[i])
            if (row.visibility == View.VISIBLE) {
                val aptName = prefs.getString("lockscreen_name_$i", "") ?: ""
                val regionCode = prefs.getString("lockscreen_regioncode_$i", "") ?: ""
                row.setOnClickListener { dismiss("detail:$interest:$regionCode:$aptName") }
            } else {
                row.setOnClickListener(null)
            }
        }

        findViewById<LinearLayout>(R.id.ls_card)?.setOnClickListener {
            val route = when (interest) {
                "subscription" -> "subscription"
                "jeonse" -> "market:jeonse"
                "monthly" -> "market:monthly"
                else -> "market:buy"
            }
            dismiss(route)
        }
    }
}
