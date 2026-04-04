# Android 잠금화면 정보 표시 + TDS 디자인 시스템 적용 가이드

> 집잇(Zipit) 프로젝트에서 검증된 구현을 기반으로 작성
> Flutter + Android Native (Kotlin) 하이브리드 구조

---

## 목차

1. [잠금화면 구현 아키텍처](#1-잠금화면-구현-아키텍처)
2. [Android Native 코드](#2-android-native-코드)
3. [Flutter ↔ Native 통신](#3-flutter--native-통신)
4. [AndroidManifest 설정](#4-androidmanifest-설정)
5. [잠금화면 UI 레이아웃](#5-잠금화면-ui-레이아웃)
6. [API 레벨별 제약사항과 해결법](#6-api-레벨별-제약사항과-해결법)
7. [TDS (Toss Design System) 적용](#7-tds-toss-design-system-적용)
8. [체크리스트](#8-체크리스트)

---

## 1. 잠금화면 구현 아키텍처

### 전체 흐름

```
[Flutter App]
    │
    ├── MethodChannel("com.zipit.app/lockscreen")
    │       ├── enableLockScreen()  → 데이터 저장 + 서비스 시작
    │       ├── updateData()        → 데이터만 갱신
    │       └── disableLockScreen() → 서비스 중단
    │
    ▼
[MainActivity] ─── SCREEN_OFF 수신 ──→ [LockScreenActivity] 직접 실행
    │                                        │
    │                                        ├── setShowWhenLocked(true)
    │                                        ├── SharedPreferences에서 데이터 로드
    │                                        ├── 스와이프로 잠금 해제
    │                                        └── 항목 탭 → 앱 내 화면으로 이동
    ▼
[LockScreenService] (Foreground Service)
    │
    └── [ScreenReceiver] ─── SCREEN_OFF ──→ LockScreenActivity (fallback)
```

### 핵심 원리

- **화면 꺼짐(SCREEN_OFF)** 이벤트를 감지하여 **LockScreenActivity**를 시작
- `setShowWhenLocked(true)`로 키가드(잠금화면) 위에 Activity 표시
- **Foreground Service**로 앱이 백그라운드에서도 SCREEN_OFF 수신 가능
- **MainActivity에서 직접 실행**하는 것이 핵심 (API 36 BAL 제한 우회)

---

## 2. Android Native 코드

### 2-1. LockScreenActivity.kt

잠금화면 위에 표시되는 Activity. SharedPreferences에서 데이터를 읽어 Native XML 레이아웃으로 표시.

```kotlin
package com.example.app

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
        // 중복 실행 방지 플래그
        @Volatile var isActive = false
    }

    private var unlockReceiver: BroadcastReceiver? = null
    private var swipeStartY = 0f
    private var swipeStartX = 0f
    private var swiping = false
    private var isDismissing = false
    private var lastDataHash = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        // ★ 핵심: 잠금화면 위에 표시
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        }

        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_lockscreen)

        // 전체화면 (onCreate에서 한 번만 - onResume에서 반복 호출하면 깜빡임 발생)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.let {
                it.hide(
                    android.view.WindowInsets.Type.statusBars() or
                    android.view.WindowInsets.Type.navigationBars()
                )
                it.systemBarsBehavior =
                    android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        }

        lastDataHash = computeDataHash()
        refreshUI()

        // 사용자가 시스템 잠금해제(PIN/패턴/지문) 완료 시 자동 종료
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

    // ── 스와이프 감지 (위로 스와이프하면 잠금 해제) ──

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
                    dismiss(null) // route 없이 → 단순 잠금 해제
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
            Log.e("LockScreen", "Failed to launch app", e)
        }
    }

    // ── UI 갱신 ──

    private fun computeDataHash(): Int {
        val prefs = getSharedPreferences("LockScreenPrefs", Context.MODE_PRIVATE)
        val sb = StringBuilder()
        sb.append(prefs.getString("title", "") ?: "")
        for (i in 0 until 3) {
            sb.append(prefs.getString("name_$i", "") ?: "")
            sb.append(prefs.getString("value_$i", "") ?: "")
            sb.append(prefs.getString("sub_$i", "") ?: "")
        }
        return sb.toString().hashCode()
    }

    private fun refreshUI() {
        val prefs = getSharedPreferences("LockScreenPrefs", Context.MODE_PRIVATE)
        // TODO: 프로젝트에 맞게 UI 바인딩 구현
        // findViewById<TextView>(R.id.title).text = prefs.getString("title", "")
        // ...
    }
}
```

**주요 포인트:**
- `setShowWhenLocked(true)` — 잠금화면 위에 Activity 표시 (API 27+)
- `isActive` static 플래그 — 중복 실행 방지
- `requestDismissKeyguard()` — PIN/패턴 입력 창 호출 후 앱 화면으로 이동
- `finishAndRemoveTask()` — 최근 앱 목록에 남지 않도록 정리
- `overridePendingTransition(0, 0)` — 전환 애니메이션 제거 (깜빡임 방지)
- **onResume이 아닌 onCreate에서만** 전체화면 설정 (반복 호출 시 깜빡임)

### 2-2. LockScreenService.kt

Foreground Service로 백그라운드에서도 SCREEN_OFF를 수신.

```kotlin
package com.example.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class LockScreenService : Service() {
    companion object {
        private const val CHANNEL_ID = "lockscreen_service"
        private const val NOTIF_ID = 9998

        fun start(context: Context) {
            val intent = Intent(context, LockScreenService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, LockScreenService::class.java))
        }
    }

    private var screenReceiver: ScreenReceiver? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startForeground(NOTIF_ID, buildNotification())

        // ★ 핵심: RECEIVER_EXPORTED로 시스템 브로드캐스트 수신 (API 34+)
        screenReceiver = ScreenReceiver()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenReceiver, filter, Context.RECEIVER_EXPORTED)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY // 시스템에 의해 종료되면 자동 재시작
    }

    override fun onDestroy() {
        screenReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
        screenReceiver = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID, "잠금화면 서비스", NotificationManager.IMPORTANCE_MIN
        ).apply {
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher) // 앱 아이콘으로 변경
            .setContentTitle("잠금화면 활성화 중")
            .setContentText("잠금화면에서 정보를 확인하세요")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setSilent(true)
            .setOngoing(true)
            .build()
    }
}
```

**주요 포인트:**
- `IMPORTANCE_MIN` — 알림이 거의 보이지 않음 (사일런트)
- `START_STICKY` — 시스템이 서비스를 종료해도 자동 재시작
- `Context.RECEIVER_EXPORTED` — API 34+에서 시스템 브로드캐스트(SCREEN_OFF) 수신에 필수

### 2-3. ScreenReceiver.kt

Fallback용 BroadcastReceiver. MainActivity가 없을 때(앱이 완전 백그라운드) 사용.

```kotlin
package com.example.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class ScreenReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_SCREEN_OFF) return

        val prefs = context.getSharedPreferences("LockScreenPrefs", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("enabled", false)) return
        if ((prefs.getString("name_0", "") ?: "").isEmpty()) return
        if (LockScreenActivity.isActive) return

        // ★ API 36에서는 실패할 수 있음 (BAL_BLOCK)
        // MainActivity에서 직접 실행하는 것이 메인 경로
        Log.d("LockScreen", "ScreenReceiver: SCREEN_OFF fallback attempt")
        try {
            val activityIntent = Intent(context, LockScreenActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION
            }
            context.startActivity(activityIntent)
        } catch (e: Exception) {
            Log.d("LockScreen", "Fallback failed (expected on API 36): ${e.message}")
        }
    }
}
```

### 2-4. MainActivity.kt (잠금화면 관련 부분)

**가장 중요한 파일.** SCREEN_OFF 시 보이는 Activity(MainActivity)에서 LockScreenActivity를 직접 실행.

```kotlin
package com.example.app

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
        private const val CHANNEL = "com.example.app/lockscreen"
        private const val NAV_CHANNEL = "com.example.app/navigation"
    }

    private var navChannel: MethodChannel? = null
    private var pendingRoute: String? = null

    // ★ 핵심: 화면 꺼질 때 LockScreenActivity를 직접 실행
    // MainActivity가 보이는 상태에서 시작하므로 BAL 제한 없음
    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_OFF) {
                val prefs = ctx.getSharedPreferences("LockScreenPrefs", Context.MODE_PRIVATE)
                if (prefs.getBoolean("enabled", false)
                    && (prefs.getString("name_0", "") ?: "").isNotEmpty()
                    && !LockScreenActivity.isActive) {
                    val lockIntent = Intent(ctx, LockScreenActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                Intent.FLAG_ACTIVITY_NO_ANIMATION
                    }
                    startActivity(lockIntent)
                }
                moveTaskToBack(true) // 앱을 뒤로 보내서 잠금화면 뒤에 안 비치게
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
                        val names = call.argument<List<String>>("names") ?: emptyList()
                        val values = call.argument<List<String>>("values") ?: emptyList()
                        // SharedPreferences에 저장
                        saveLockScreenData(title, names, values)
                        // Foreground Service 시작
                        try { LockScreenService.start(this) } catch (e: Exception) {
                            Log.e("LockScreen", "Failed to start service", e)
                        }
                        result.success(true)
                    }
                    "disableLockScreen" -> {
                        val prefs = getSharedPreferences("LockScreenPrefs", Context.MODE_PRIVATE)
                        prefs.edit().putBoolean("enabled", false).apply()
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

        handleIntent(intent)
        restoreLockScreenServiceIfNeeded()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    // 잠금화면에서 항목 탭 → 앱 내 특정 화면으로 이동
    private fun handleIntent(intent: Intent) {
        val route = intent.getStringExtra("lockscreen_route")
        if (route != null) {
            if (navChannel != null) {
                navChannel?.invokeMethod("navigate", route)
            } else {
                pendingRoute = route
            }
            intent.removeExtra("lockscreen_route")
        }
    }

    // 앱 재시작 시 서비스 복구
    private fun restoreLockScreenServiceIfNeeded() {
        val prefs = getSharedPreferences("LockScreenPrefs", Context.MODE_PRIVATE)
        if (prefs.getBoolean("enabled", false)
            && (prefs.getString("name_0", "") ?: "").isNotEmpty()) {
            try { LockScreenService.start(this) } catch (_: Exception) {}
        }
    }

    private fun saveLockScreenData(
        title: String,
        names: List<String>,
        values: List<String>
    ) {
        val prefs = getSharedPreferences("LockScreenPrefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putBoolean("enabled", true)
            putString("title", title)
            for (i in 0 until 3) {
                putString("name_$i", if (i < names.size) names[i] else "")
                putString("value_$i", if (i < values.size) values[i] else "")
            }
            apply()
        }
    }
}
```

**핵심 패턴: `moveTaskToBack(true)` 전에 LockScreenActivity를 시작**
- `callingUidHasVisibleActivity: true` → BAL 제한 우회
- 그 후 `moveTaskToBack(true)` → Flutter 앱이 잠금화면 뒤에 비치지 않음

---

## 3. Flutter ↔ Native 통신

### Dart 측 (notification_service.dart 일부)

```dart
import 'package:flutter/services.dart';

class LockScreenBridge {
  static const _channel = MethodChannel('com.example.app/lockscreen');

  /// 잠금화면 활성화 + 데이터 저장 + 서비스 시작
  static Future<void> enable({
    required String title,
    required List<String> names,
    required List<String> values,
  }) async {
    if (names.isEmpty) return;
    try {
      await _channel.invokeMethod('enableLockScreen', {
        'title': title,
        'names': names.take(3).toList(),
        'values': values.take(3).toList(),
      });
    } catch (_) {}
  }

  /// 잠금화면 비활성화
  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disableLockScreen');
    } catch (_) {}
  }
}
```

### 딥링크 수신 (main.dart)

```dart
// 잠금화면 항목 탭 → 앱 내 특정 화면으로 라우팅
void _setupLockScreenNavigation() {
  const navChannel = MethodChannel('com.example.app/navigation');
  navChannel.setMethodCallHandler((call) async {
    if (call.method == 'navigate') {
      final route = call.arguments as String;
      // route 파싱 후 go_router 등으로 이동
      _handleLockScreenRoute(route);
    }
  });
}

// 앱 시작 시 pending route 확인
Future<void> _checkPendingRoute() async {
  const channel = MethodChannel('com.example.app/lockscreen');
  final route = await channel.invokeMethod<String>('getPendingRoute');
  if (route != null) _handleLockScreenRoute(route);
}
```

---

## 4. AndroidManifest 설정

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- 필수 권한 -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"/>

    <application ...>
        <!-- 메인 Activity -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            ...>
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <!-- ★ 잠금화면 Activity -->
        <activity
            android:name=".LockScreenActivity"
            android:exported="false"
            android:excludeFromRecents="true"
            android:showOnLockScreen="true"
            android:taskAffinity="com.example.app.lockscreen"
            android:theme="@style/LockScreenTheme" />

        <!-- ★ Foreground Service (specialUse 타입) -->
        <service
            android:name=".LockScreenService"
            android:exported="false"
            android:foregroundServiceType="specialUse" />
    </application>
</manifest>
```

### styles.xml - 잠금화면 테마

```xml
<!-- 잠금화면 Activity 테마: 검은 배경 + 전체화면 + 전환 애니메이션 없음 -->
<style name="LockScreenTheme" parent="@android:style/Theme.NoTitleBar.Fullscreen">
    <item name="android:windowBackground">#FF0D0D1A</item>
    <item name="android:windowIsTranslucent">false</item>
    <item name="android:windowIsFloating">false</item>
    <item name="android:windowNoTitle">true</item>
    <item name="android:windowFullscreen">true</item>
    <item name="android:windowAnimationStyle">@null</item>
    <item name="android:windowDisablePreview">false</item>
    <item name="android:colorBackground">#FF0D0D1A</item>
    <item name="android:navigationBarColor">#FF0D0D1A</item>
    <item name="android:statusBarColor">#00000000</item>
    <item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>
</style>
```

**깜빡임 방지 핵심:**
- `windowAnimationStyle: @null` — 전환 애니메이션 제거
- `windowIsTranslucent: false` — 투명 창 깜빡임 방지
- `windowDisablePreview: false` — 미리보기 활성화 (검은 배경 즉시 표시)
- `windowBackground`와 `colorBackground` 동일 색상 — 전환 시 색상 차이 없음

---

## 5. 잠금화면 UI 레이아웃

### activity_lockscreen.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#FF0D0D1A">

    <!-- 상단: 시계 + 날짜 -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="vertical"
        android:gravity="center_horizontal"
        android:paddingTop="100dp">

        <TextClock
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:format12Hour="h:mm"
            android:format24Hour="HH:mm"
            android:textColor="#FFFFFFFF"
            android:textSize="72sp"
            android:fontFamily="sans-serif-thin" />

        <TextClock
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:format12Hour="M월 d일 (EEE)"
            android:format24Hour="M월 d일 (EEE)"
            android:textColor="#99FFFFFF"
            android:textSize="16sp"
            android:layout_marginTop="8dp" />
    </LinearLayout>

    <!-- 중앙: 정보 카드 -->
    <LinearLayout
        android:id="@+id/ls_card"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_gravity="center"
        android:orientation="vertical"
        android:layout_marginHorizontal="20dp"
        android:padding="20dp"
        android:background="@drawable/lockscreen_card_bg"
        android:clickable="true"
        android:focusable="true">

        <!-- 헤더 -->
        <LinearLayout ...>
            <TextView android:text="🏠" android:textSize="20sp" />
            <TextView
                android:text="앱이름"
                android:textColor="#FF3182F6"
                android:textSize="17sp"
                android:textStyle="bold" />
            <TextView
                android:id="@+id/ls_title"
                android:textColor="#99FFFFFF"
                android:textSize="13sp"
                android:gravity="end" />
        </LinearLayout>

        <!-- 구분선 -->
        <View
            android:layout_width="match_parent"
            android:layout_height="1dp"
            android:background="#1AFFFFFF" />

        <!-- 데이터 행 (최대 3개) -->
        <LinearLayout android:id="@+id/ls_row_1" android:visibility="gone" ...>
            <TextView android:id="@+id/ls_name_1" android:textColor="#FFFFFFFF" />
            <TextView android:id="@+id/ls_price_1" android:textColor="#FF3182F6" />
            <TextView android:id="@+id/ls_date_1" android:textColor="#66FFFFFF" />
        </LinearLayout>
        <!-- ls_row_2, ls_row_3 동일 구조 -->
    </LinearLayout>

    <!-- 하단: 스와이프 안내 -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_gravity="bottom"
        android:gravity="center_horizontal"
        android:layout_marginBottom="48dp">
        <TextView android:text="위로 스와이프하여 잠금 해제"
            android:textColor="#44FFFFFF" android:textSize="12sp" />
    </LinearLayout>
</FrameLayout>
```

### lockscreen_card_bg.xml (drawable)

```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <corners android:radius="20dp" />
    <solid android:color="#FF1A1A2E" />
    <stroke android:width="1dp" android:color="#1AFFFFFF" />
</shape>
```

---

## 6. API 레벨별 제약사항과 해결법

### API 27 (O_MR1) — `setShowWhenLocked(true)` 도입

```kotlin
// API 27+
setShowWhenLocked(true)

// API 26 이하
window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
```

### API 34 — BroadcastReceiver export 필수

```kotlin
// API 34+: SCREEN_OFF 같은 시스템 브로드캐스트도 export 플래그 필요
registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)

// Activity 내부 전용 (USER_PRESENT 등)
registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
```

### API 36 — Background Activity Launch(BAL) 차단

**문제:** `callingUidHasVisibleActivity: false`일 때 Activity 시작 불가

```
W/ActivityTaskManager: BAL_BLOCK {
    callingUid=10XXX, callingPkg=com.example.app,
    callingUidHasVisibleActivity: false,
    intent=Intent { act=...LockScreenActivity }
}
```

**해결:** MainActivity의 screenOffReceiver에서 직접 시작 (visible Activity에서 호출)

```
SCREEN_OFF 이벤트 발생
  ↓
MainActivity.screenOffReceiver.onReceive()  ← callingUidHasVisibleActivity: true
  ↓
startActivity(LockScreenActivity)  ← BAL 통과!
  ↓
moveTaskToBack(true)  ← 순서 중요: Activity 시작 후 뒤로 보내기
```

### fullScreenIntent는 쓰지 마세요

API 36에서 `fullScreenIntent`는 알람/전화 앱만 자동 실행됨. 일반 앱은 알림만 표시.

---

## 7. TDS (Toss Design System) 적용

### 7-1. 컬러 시스템

```dart
/// TDS 기반 컬러 팔레트
class AppColors {
  // Primary
  static const Color primary = Color(0xFF3182F6);       // 토스 블루
  static const Color primaryLight = Color(0xFF5B9CF6);
  static const Color primaryDark = Color(0xFF1B64DA);

  // Semantic (시그널)
  static const Color success = Color(0xFF2BD97C);       // 안전 (초록)
  static const Color warning = Color(0xFFF59E0B);       // 주의 (노랑)
  static const Color error = Color(0xFFFF4545);         // 위험 (빨강)

  // Grayscale (10단계)
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF2F4F6);
  static const Color gray200 = Color(0xFFE5E8EB);
  static const Color gray300 = Color(0xFFD1D6DB);
  static const Color gray400 = Color(0xFFB0B8C1);
  static const Color gray500 = Color(0xFF8B95A1);
  static const Color gray600 = Color(0xFF6B7684);
  static const Color gray700 = Color(0xFF4E5968);
  static const Color gray800 = Color(0xFF333D4B);
  static const Color gray900 = Color(0xFF191F28);

  // 역할 기반 (Semantic tokens)
  static const Color background = Color(0xFFF9FAFB);    // = gray50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF191F28);    // = gray900
  static const Color textSecondary = Color(0xFF4E5968);  // = gray700
  static const Color textTertiary = Color(0xFF8B95A1);   // = gray500
  static const Color textDisabled = Color(0xFFB0B8C1);   // = gray400
  static const Color border = Color(0xFFE5E8EB);         // = gray200
  static const Color borderLight = Color(0xFFF2F4F6);    // = gray100
  static const Color borderFocused = Color(0xFF3182F6);  // = primary
  static const Color dim = Color(0x52000000);             // 32% 블랙
}
```

### 7-2. 타이포그래피

폰트: **Pretendard** (토스에서 공개한 오픈소스 폰트)

```dart
class AppTypography {
  static const String _fontFamily = 'Pretendard';

  // Heading — 페이지 타이틀, 섹션 헤더
  static const TextStyle heading1 = TextStyle(
    fontFamily: _fontFamily, fontSize: 26, fontWeight: FontWeight.w700,
    height: 1.35, letterSpacing: -0.3, color: AppColors.textPrimary,
  );
  static const TextStyle heading2 = TextStyle(
    fontFamily: _fontFamily, fontSize: 22, fontWeight: FontWeight.w700,
    height: 1.35, letterSpacing: -0.3,
  );
  static const TextStyle heading3 = TextStyle(
    fontFamily: _fontFamily, fontSize: 20, fontWeight: FontWeight.w600,
    height: 1.4, letterSpacing: -0.3,
  );

  // Body — 본문 텍스트
  static const TextStyle body1 = TextStyle(
    fontFamily: _fontFamily, fontSize: 17, fontWeight: FontWeight.w400,
    height: 1.5, letterSpacing: -0.3,
  );
  static const TextStyle body1Bold = TextStyle(
    fontFamily: _fontFamily, fontSize: 17, fontWeight: FontWeight.w600,
    height: 1.5, letterSpacing: -0.3,
  );
  static const TextStyle body2 = TextStyle(
    fontFamily: _fontFamily, fontSize: 15, fontWeight: FontWeight.w400,
    height: 1.5, letterSpacing: -0.3,
  );
  static const TextStyle body2Bold = TextStyle(
    fontFamily: _fontFamily, fontSize: 15, fontWeight: FontWeight.w600,
    height: 1.5, letterSpacing: -0.3,
  );

  // Caption — 보조 텍스트, 날짜, 메타 정보
  static const TextStyle caption1 = TextStyle(
    fontFamily: _fontFamily, fontSize: 13, fontWeight: FontWeight.w400,
    height: 1.5, letterSpacing: -0.3, color: AppColors.textTertiary,
  );
  static const TextStyle caption2 = TextStyle(
    fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w400,
    height: 1.45, letterSpacing: -0.3, color: AppColors.textTertiary,
  );

  // Label — 버튼, 칩, 탭
  static const TextStyle label1 = TextStyle(
    fontFamily: _fontFamily, fontSize: 17, fontWeight: FontWeight.w600,
    height: 1.4, letterSpacing: -0.3,
  );
  static const TextStyle label2 = TextStyle(
    fontFamily: _fontFamily, fontSize: 15, fontWeight: FontWeight.w600,
    height: 1.4, letterSpacing: -0.3,
  );

  // Number — 가격, 금액, 통계 수치
  static const TextStyle number1 = TextStyle(
    fontFamily: _fontFamily, fontSize: 28, fontWeight: FontWeight.w700,
    height: 1.3, letterSpacing: -0.3,
  );
  static const TextStyle number2 = TextStyle(
    fontFamily: _fontFamily, fontSize: 22, fontWeight: FontWeight.w700,
    height: 1.3, letterSpacing: -0.3,
  );
}
```

### 7-3. 스페이싱 시스템

```dart
class AppSpacing {
  // 기본 간격 (4px 단위)
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  // 화면 패딩
  static const double screenH = 20.0;   // 좌우
  static const double screenV = 24.0;   // 상하

  // 컴포넌트
  static const double cardPadding = 16.0;
  static const double cardRadius = 16.0;
  static const double buttonHeight = 56.0;
  static const double buttonSmallHeight = 40.0;

  // 라운드
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusFull = 999.0;  // 완전 라운드
}
```

### 7-4. 테마 통합 (AppTheme)

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Pretendard',
    scaffoldBackgroundColor: AppColors.background,

    // 컬러 스킴
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    ),

    // 앱바: 흰 배경 + 그림자 없음
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: AppTypography.body1Bold,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
      ),
    ),

    // 하단 네비게이션
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.textPrimary,
      unselectedItemColor: AppColors.textTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
    ),

    // 버튼 (Primary)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.gray200,
        disabledForegroundColor: AppColors.gray400,
        elevation: 0,
        minimumSize: Size(double.infinity, AppSpacing.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        textStyle: AppTypography.label1.copyWith(color: AppColors.white),
      ),
    ),

    // 버튼 (Secondary)
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        minimumSize: Size(double.infinity, AppSpacing.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        side: BorderSide(color: AppColors.border),
      ),
    ),

    // 텍스트필드
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.gray100,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: BorderSide(color: AppColors.borderFocused, width: 1.5),
      ),
      hintStyle: AppTypography.body1.copyWith(color: AppColors.textTertiary),
    ),

    // 칩 (필터 등)
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.gray100,
      selectedColor: AppColors.primary.withOpacity(0.1),
      labelStyle: AppTypography.label2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      side: BorderSide.none,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    // 구분선
    dividerTheme: const DividerThemeData(
      color: AppColors.borderLight,
      thickness: 1,
      space: 0,
    ),

    // 바텀시트
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
  );
}
```

### 7-5. TDS 디자인 원칙 요약

| 원칙 | 적용 방법 |
|------|----------|
| **여백은 넉넉하게** | `screenH: 20`, `cardPadding: 16`, 컴포넌트 간 `12~16px` |
| **그림자 대신 배경색** | `elevation: 0`, 카드는 `surface` 위에 `background` |
| **둥근 모서리** | 카드 `16dp`, 버튼 `12dp`, 칩 `999dp` |
| **정보 계층** | `textPrimary` → `textSecondary` → `textTertiary` 3단계 |
| **최소 색상** | primary(파랑) + semantic(초록/노랑/빨강) + grayscale |
| **letterSpacing: -0.3** | 모든 텍스트에 적용 → 자연스러운 한글 가독성 |
| **line-height** | heading: 1.35, body: 1.5, caption: 1.45~1.5 |

---

## 8. 체크리스트

### 잠금화면 구현 시

- [ ] `setShowWhenLocked(true)` (API 27+ / fallback FLAG)
- [ ] `LockScreenTheme` — `windowAnimationStyle: @null` + 배경색 통일
- [ ] `taskAffinity` — 메인 앱과 별도 태스크로 분리
- [ ] `excludeFromRecents: true` — 최근 앱에 안 보이게
- [ ] Foreground Service — `specialUse` 타입 + `IMPORTANCE_MIN`
- [ ] `RECEIVER_EXPORTED` — API 34+ 시스템 브로드캐스트 수신
- [ ] BAL 우회 — MainActivity에서 직접 Activity 시작 (API 36+)
- [ ] `isActive` 플래그 — 중복 실행 방지
- [ ] `requestDismissKeyguard()` — 잠금 해제 콜백 처리
- [ ] `ACTION_USER_PRESENT` — 시스템 잠금해제 시 Activity 자동 종료
- [ ] 서비스 자동 복구 — 앱 재시작 시 `restoreLockScreenServiceIfNeeded()`
- [ ] 설정 토글 OFF → `disableLockScreen()` 호출 (서비스 중단)

### TDS 적용 시

- [ ] Pretendard 폰트 설치 (`pubspec.yaml` fonts 섹션)
- [ ] `AppColors`, `AppTypography`, `AppSpacing` 상수 파일 생성
- [ ] `AppTheme.light`를 `MaterialApp`에 적용
- [ ] 하드코딩된 색상/사이즈 → 상수 참조로 변환
- [ ] 컬러는 역할 기반 토큰 사용 (`textPrimary` > `gray900`)

### Play Store 배포 시 주의

- [ ] `FOREGROUND_SERVICE_SPECIAL_USE` — Play Console에서 사용 사유 설명 필요
- [ ] 테스트 트랙에서 먼저 검증 (영상 제출 필요할 수 있음)
- [ ] `SYSTEM_ALERT_WINDOW` 권한은 **불필요** (overlay 방식 아님)
- [ ] `USE_FULL_SCREEN_INTENT` 권한은 **불필요** (fullScreenIntent 방식 아님)
