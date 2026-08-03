package com.edubot.edubot_mobile

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 12+ always shows a system splash and, by default, plays a
        // zoom/fade EXIT animation when handing off to the app — which reads as
        // a "second splash" before our Flutter one. Remove the splash view
        // instantly instead, so the hand-off to our Flutter splash is seamless.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { view -> view.remove() }
        }
    }
}
