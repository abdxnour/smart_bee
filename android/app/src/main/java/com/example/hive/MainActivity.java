package com.example.hive;

import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.PowerManager;
import android.provider.Settings;
import androidx.core.app.NotificationManagerCompat;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.example.hive/settings";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler(
                (call, result) -> {
                    if (call.method.equals("openBatterySettings")) {
                        openBatterySettings();
                        result.success(true);
                    } else if (call.method.equals("isBatteryOptimizationIgnored")) {
                        result.success(isBatteryOptimizationIgnored());
                    } else if (call.method.equals("areNotificationsEnabled")) {
                        result.success(areNotificationsEnabled());
                    } else {
                        result.notImplemented();
                    }
                }
            );
    }

    private boolean isBatteryOptimizationIgnored() {
        String packageName = getPackageName();
        PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
        if (pm != null) {
            return pm.isIgnoringBatteryOptimizations(packageName);
        }
        return false;
    }

    private boolean areNotificationsEnabled() {
        return NotificationManagerCompat.from(this).areNotificationsEnabled();
    }

    private void openBatterySettings() {
        Intent intent = new Intent();
        String packageName = getPackageName();
        if (isBatteryOptimizationIgnored()) {
            intent.setAction(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
        } else {
            intent.setAction(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
            intent.setData(Uri.parse("package:" + packageName));
        }
        startActivity(intent);
    }
}
