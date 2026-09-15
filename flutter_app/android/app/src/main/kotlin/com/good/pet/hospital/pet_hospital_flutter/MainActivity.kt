package com.good.pet.hospital

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingLocationResult: MethodChannel.Result? = null
    private var activeLocationListener: LocationListener? = null
    private var locationTimeout: Runnable? = null
    private var videoSurfaceExitBridge: VideoSurfaceExitBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        videoSurfaceExitBridge = VideoSurfaceExitBridge(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.good.pet.hospital/external_uri",
        ).setMethodCallHandler { call, result ->
            val rawUri = call.argument<String>("uri")
            val uri = rawUri?.let(Uri::parse)
            if (uri == null || !isAllowedExternalUri(uri)) {
                result.success(false)
                return@setMethodCallHandler
            }

            val intent = externalUriIntent(uri)
            when (call.method) {
                "canLaunchUri" -> {
                    try {
                        result.success(intent.resolveActivity(packageManager) != null)
                    } catch (_: RuntimeException) {
                        result.success(false)
                    }
                }
                "launchUri" -> {
                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (_: RuntimeException) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.good.pet.hospital/emergency_location",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> result.success(locationPermissionStatus())
                "requestPermission" -> requestLocationPermission(result)
                "getCurrentLocation" -> getCurrentLocation(result)
                "cancelCurrentLocation" -> {
                    cancelLocationRequest()
                    result.success(null)
                }
                "openSettings" -> openApplicationSettings(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.good.pet.hospital/activity_share_poster",
        ).setMethodCallHandler { call, result ->
            if (call.method != "savePng") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val bytes = call.argument<ByteArray>("bytes")
            if (bytes == null || bytes.isEmpty()) {
                result.error("invalid_image", "活动海报数据无效", null)
                return@setMethodCallHandler
            }
            Thread {
                try {
                    saveActivityPoster(bytes)
                    runOnUiThread { result.success(true) }
                } catch (error: SecurityException) {
                    runOnUiThread {
                        result.error("permission_denied", "未授予相册写入权限", null)
                    }
                } catch (error: Exception) {
                    runOnUiThread {
                        result.error(
                            "save_failed",
                            error.message ?: "活动海报保存失败",
                            null,
                        )
                    }
                }
            }.start()
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.good.pet.hospital/background_media_upload",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enqueue" -> {
                    val task = BackgroundMediaUploadTask.fromArguments(call.arguments)
                    if (task == null) {
                        result.error("invalid_task", "媒体上传任务参数无效", null)
                        return@setMethodCallHandler
                    }
                    try {
                        BackgroundMediaUploadService.enqueue(this, task)
                        result.success(task.taskId)
                    } catch (error: Exception) {
                        result.error(
                            "enqueue_failed",
                            error.message ?: "无法启动后台媒体上传",
                            null,
                        )
                    }
                }
                "status" -> {
                    val taskId = call.argument<String>("taskId")
                    if (taskId.isNullOrBlank()) {
                        result.error("invalid_task", "媒体上传任务标识无效", null)
                        return@setMethodCallHandler
                    }
                    result.success(BackgroundMediaUploadStore.status(this, taskId))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != LOCATION_PERMISSION_REQUEST_CODE) return
        pendingPermissionResult?.success(locationPermissionStatus())
        pendingPermissionResult = null
    }

    override fun onDestroy() {
        videoSurfaceExitBridge?.close()
        videoSurfaceExitBridge = null
        clearLocationRequest()
        pendingPermissionResult?.error("activity_destroyed", "页面已关闭", null)
        pendingPermissionResult = null
        super.onDestroy()
    }

    private fun requestLocationPermission(result: MethodChannel.Result) {
        if (hasLocationPermission()) {
            result.success("granted")
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_request_busy", "位置权限请求正在进行", null)
            return
        }
        getSharedPreferences(PERMISSION_PREFERENCES, MODE_PRIVATE)
            .edit()
            .putBoolean(LOCATION_PERMISSION_REQUESTED, true)
            .apply()
        pendingPermissionResult = result
        requestPermissions(
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
            LOCATION_PERMISSION_REQUEST_CODE,
        )
    }

    private fun locationPermissionStatus(): String {
        if (hasLocationPermission()) return "granted"
        val requested = getSharedPreferences(PERMISSION_PREFERENCES, MODE_PRIVATE)
            .getBoolean(LOCATION_PERMISSION_REQUESTED, false)
        val shouldExplain = shouldShowRequestPermissionRationale(
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) || shouldShowRequestPermissionRationale(
            Manifest.permission.ACCESS_COARSE_LOCATION,
        )
        return if (requested && !shouldExplain) "blocked" else "denied"
    }

    private fun hasLocationPermission(): Boolean {
        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun getCurrentLocation(result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            result.error("permission_denied", "位置权限未授予", null)
            return
        }
        if (pendingLocationResult != null) {
            result.error("location_request_busy", "正在获取当前位置", null)
            return
        }
        val manager = getSystemService(LOCATION_SERVICE) as LocationManager
        val providers = listOf(
            LocationManager.NETWORK_PROVIDER,
            LocationManager.GPS_PROVIDER,
        ).filter { manager.isProviderEnabled(it) }
        if (providers.isEmpty()) {
            result.error("location_disabled", "系统定位服务未开启", null)
            return
        }

        try {
            val cached = providers
                .mapNotNull { provider ->
                    manager.getLastKnownLocation(provider)
                        ?.takeIf { location -> isUsableLocation(location) }
                }
                .maxByOrNull { it.time }
            if (cached != null && System.currentTimeMillis() - cached.time <= LOCATION_CACHE_TTL_MS) {
                result.success(locationPayload(cached))
                return
            }

            pendingLocationResult = result
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    completeLocation(location)
                }

                @Suppress("OVERRIDE_DEPRECATION")
                @Deprecated("Deprecated in Android")
                override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

                override fun onProviderEnabled(provider: String) = Unit

                @Deprecated("Deprecated in Android")
                override fun onProviderDisabled(provider: String) = Unit
            }
            activeLocationListener = listener
            for (provider in providers) {
                manager.requestLocationUpdates(
                    provider,
                    0L,
                    0f,
                    listener,
                    Looper.getMainLooper(),
                )
            }
            val timeout = Runnable {
                failLocation("location_timeout", "获取当前位置超时")
            }
            locationTimeout = timeout
            Handler(Looper.getMainLooper()).postDelayed(timeout, LOCATION_TIMEOUT_MS)
        } catch (_: SecurityException) {
            clearLocationRequest()
            result.error("permission_denied", "位置权限未授予", null)
        } catch (error: Exception) {
            clearLocationRequest()
            result.error("location_failed", error.message ?: "无法获取当前位置", null)
        }
    }

    private fun completeLocation(location: Location) {
        val result = pendingLocationResult ?: return
        if (!isUsableLocation(location)) return
        pendingLocationResult = null
        clearLocationRequest()
        result.success(locationPayload(location))
    }

    private fun failLocation(code: String, message: String) {
        val result = pendingLocationResult ?: return
        pendingLocationResult = null
        clearLocationRequest()
        result.error(code, message, null)
    }

    private fun clearLocationRequest() {
        locationTimeout?.let { Handler(Looper.getMainLooper()).removeCallbacks(it) }
        locationTimeout = null
        val listener = activeLocationListener
        activeLocationListener = null
        if (listener != null) {
            val manager = getSystemService(LOCATION_SERVICE) as LocationManager
            try {
                manager.removeUpdates(listener)
            } catch (_: SecurityException) {
                // 权限可能在请求过程中被系统回收。
            }
        }
    }

    private fun cancelLocationRequest() {
        val result = pendingLocationResult
        pendingLocationResult = null
        clearLocationRequest()
        result?.error("location_cancelled", "定位请求已取消", null)
    }

    private fun locationPayload(location: Location): Map<String, Double> {
        return mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
        )
    }

    private fun isUsableLocation(location: Location): Boolean {
        return location.latitude in -90.0..90.0 &&
            location.longitude in -180.0..180.0 &&
            (location.latitude != 0.0 || location.longitude != 0.0)
    }

    private fun openApplicationSettings(result: MethodChannel.Result) {
        try {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:$packageName"),
                ),
            )
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            result.success(false)
        }
    }

    private fun isAllowedExternalUri(uri: Uri): Boolean {
        return when (uri.scheme?.lowercase()) {
            "http", "https" -> !uri.host.isNullOrBlank()
            "tel" -> uri.schemeSpecificPart?.isNotBlank() == true
            else -> false
        }
    }

    private fun externalUriIntent(uri: Uri): Intent {
        val action = if (uri.scheme.equals("tel", ignoreCase = true)) {
            Intent.ACTION_DIAL
        } else {
            Intent.ACTION_VIEW
        }
        return Intent(action, uri)
    }

    private fun saveActivityPoster(bytes: ByteArray) {
        val displayName = "activity_${System.currentTimeMillis()}.png"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/PetHospital",
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                values,
            ) ?: error("无法创建相册文件")
            try {
                contentResolver.openOutputStream(uri)?.use { stream ->
                    stream.write(bytes)
                } ?: error("无法写入相册文件")
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
            } catch (error: Exception) {
                contentResolver.delete(uri, null, null)
                throw error
            }
            return
        }

        val picturesDirectory = File(
            getExternalFilesDir(Environment.DIRECTORY_PICTURES),
            "PetHospital",
        )
        check(picturesDirectory.exists() || picturesDirectory.mkdirs()) {
            "无法创建海报目录"
        }
        val poster = File(picturesDirectory, displayName)
        poster.writeBytes(bytes)
        MediaScannerConnection.scanFile(
            this,
            arrayOf(poster.absolutePath),
            arrayOf("image/png"),
            null,
        )
    }

    private companion object {
        const val LOCATION_PERMISSION_REQUEST_CODE = 4102
        const val PERMISSION_PREFERENCES = "emergency_location_permission"
        const val LOCATION_PERMISSION_REQUESTED = "location_permission_requested"
        const val LOCATION_CACHE_TTL_MS = 5 * 60 * 1000L
        const val LOCATION_TIMEOUT_MS = 15 * 1000L
    }
}
