package com.good.pet.hospital

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileInputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * 通过前台服务承接大媒体上传，避免应用进入后台后由 Flutter/Dart HTTP 请求被系统暂停。
 */
class BackgroundMediaUploadService : Service() {
    private val executor = Executors.newCachedThreadPool()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val payload = intent?.getStringExtra(EXTRA_TASK)
        val task = payload?.let(BackgroundMediaUploadTask::fromJson)
        if (task == null) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        if (BackgroundMediaUploadStore.isCompleted(this, task.taskId)) {
            stopIfIdle()
            return START_NOT_STICKY
        }

        showForegroundNotification(0)
        if (!activeTaskIds.add(task.taskId)) {
            return START_REDELIVER_INTENT
        }

        BackgroundMediaUploadStore.markRunning(this, task.taskId)
        executor.execute {
            try {
                upload(task)
            } catch (error: Exception) {
                Log.w(TAG, "Background media upload failed", error)
                BackgroundMediaUploadStore.markFailed(
                    this,
                    task.taskId,
                    error.message?.takeIf { it.isNotBlank() }
                        ?: "媒体上传失败，请检查网络后重试",
                )
            } finally {
                activeTaskIds.remove(task.taskId)
                stopIfIdle()
            }
        }
        return START_REDELIVER_INTENT
    }

    override fun onDestroy() {
        super.onDestroy()
    }

    private fun upload(task: BackgroundMediaUploadTask) {
        val boundary = "----PetHospitalUpload${System.currentTimeMillis()}"
        val connection = (URL(task.url).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doInput = true
            doOutput = true
            useCaches = false
            connectTimeout = CONNECT_TIMEOUT_MS
            // 大文件的传输时间不应被 read timeout 截断。
            readTimeout = 0
            setChunkedStreamingMode(BUFFER_SIZE)
            setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
            task.headers.forEach { (name, value) -> setRequestProperty(name, value) }
        }

        try {
            val totalBytes = task.files.sumOf { File(it.path).length().coerceAtLeast(0L) }
            var transferredBytes = 0L
            var lastProgress = -1
            BufferedOutputStream(connection.outputStream).use { output ->
                task.fields.forEach { (name, value) ->
                    output.writeMultipartText(boundary, name, value)
                }
                task.files.forEach { file ->
                    output.writeMultipartFileHeader(boundary, file)
                    BufferedInputStream(FileInputStream(file.path)).use { input ->
                        val buffer = ByteArray(BUFFER_SIZE)
                        while (true) {
                            val count = input.read(buffer)
                            if (count <= 0) break
                            output.write(buffer, 0, count)
                            transferredBytes += count
                            if (totalBytes > 0) {
                                val progress =
                                    ((transferredBytes * 100) / totalBytes).toInt().coerceIn(0, 100)
                                if (progress != lastProgress) {
                                    lastProgress = progress
                                    showForegroundNotification(progress)
                                }
                            }
                        }
                    }
                    output.write(CRLF_BYTES)
                }
                output.write("--$boundary--\r\n".toByteArray(StandardCharsets.UTF_8))
                output.flush()
            }

            val statusCode = connection.responseCode
            val stream = if (statusCode in 200..299) {
                connection.inputStream
            } else {
                connection.errorStream
            }
            val responseBody = stream?.bufferedReader(StandardCharsets.UTF_8)?.use { it.readText() }.orEmpty()
            // HTTP 业务错误也要透传给 Dart 层，以保留现有接口的错误处理语义。
            BackgroundMediaUploadStore.markCompleted(
                this,
                task.taskId,
                statusCode,
                responseBody,
            )
        } finally {
            connection.disconnect()
        }
    }

    private fun BufferedOutputStream.writeMultipartText(
        boundary: String,
        name: String,
        value: String,
    ) {
        write("--$boundary\r\n".toByteArray(StandardCharsets.UTF_8))
        write(
            "Content-Disposition: form-data; name=\"${name.escapeHeader()}\"\r\n\r\n"
                .toByteArray(StandardCharsets.UTF_8),
        )
        write(value.toByteArray(StandardCharsets.UTF_8))
        write(CRLF_BYTES)
    }

    private fun BufferedOutputStream.writeMultipartFileHeader(
        boundary: String,
        file: BackgroundMediaUploadFile,
    ) {
        write("--$boundary\r\n".toByteArray(StandardCharsets.UTF_8))
        write(
            (
                "Content-Disposition: form-data; name=\"${file.field.escapeHeader()}\"; " +
                    "filename=\"${file.fileName.escapeHeader()}\"\r\n"
                ).toByteArray(StandardCharsets.UTF_8),
        )
        write("Content-Type: ${file.mimeType}\r\n\r\n".toByteArray(StandardCharsets.UTF_8))
    }

    private fun String.escapeHeader(): String = replace("\"", "_").replace("\r", "_").replace("\n", "_")

    private fun showForegroundNotification(progress: Int) {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    "媒体发送",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
        val content = if (progress in 1..99) "正在发送 $progress%" else "正在发送媒体"
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("谷德E宠")
            .setContentText(content)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(100, progress, progress == 0)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopIfIdle() {
        if (activeTaskIds.isNotEmpty()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    companion object {
        private const val TAG = "BackgroundMediaUpload"
        private const val EXTRA_TASK = "background_media_upload_task"
        private const val NOTIFICATION_CHANNEL_ID = "background_media_upload"
        private const val NOTIFICATION_ID = 42017
        private const val CONNECT_TIMEOUT_MS = 30_000
        private const val BUFFER_SIZE = 64 * 1024
        private val CRLF_BYTES = "\r\n".toByteArray(StandardCharsets.UTF_8)
        private val activeTaskIds = ConcurrentHashMap.newKeySet<String>()

        fun enqueue(context: Context, task: BackgroundMediaUploadTask) {
            if (BackgroundMediaUploadStore.isCompleted(context, task.taskId)) return
            BackgroundMediaUploadStore.markRunning(context, task.taskId)
            val intent = Intent(context, BackgroundMediaUploadService::class.java)
                .putExtra(EXTRA_TASK, task.toJson())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}

data class BackgroundMediaUploadFile(
    val field: String,
    val path: String,
    val fileName: String,
    val mimeType: String,
)

data class BackgroundMediaUploadTask(
    val taskId: String,
    val url: String,
    val headers: Map<String, String>,
    val fields: Map<String, String>,
    val files: List<BackgroundMediaUploadFile>,
) {
    fun toJson(): String = JSONObject()
        .put("taskId", taskId)
        .put("url", url)
        .put("headers", JSONObject(headers))
        .put("fields", JSONObject(fields))
        .put(
            "files",
            JSONArray().apply {
                files.forEach { file ->
                    put(
                        JSONObject()
                            .put("field", file.field)
                            .put("path", file.path)
                            .put("fileName", file.fileName)
                            .put("mimeType", file.mimeType),
                    )
                }
            },
        )
        .toString()

    companion object {
        fun fromArguments(arguments: Any?): BackgroundMediaUploadTask? {
            val values = arguments as? Map<*, *> ?: return null
            val taskId = values["taskId"] as? String ?: return null
            val url = values["url"] as? String ?: return null
            val files = (values["files"] as? List<*>)
                ?.mapNotNull { item ->
                    val file = item as? Map<*, *> ?: return@mapNotNull null
                    val field = file["field"] as? String ?: return@mapNotNull null
                    val path = file["path"] as? String ?: return@mapNotNull null
                    val fileName = file["fileName"] as? String ?: return@mapNotNull null
                    val mimeType = file["mimeType"] as? String ?: return@mapNotNull null
                    BackgroundMediaUploadFile(field, path, fileName, mimeType)
                }
                .orEmpty()
            if (taskId.isBlank() || url.isBlank() || files.isEmpty()) return null
            return BackgroundMediaUploadTask(
                taskId = taskId,
                url = url,
                headers = values["headers"].toStringMap(),
                fields = values["fields"].toStringMap(),
                files = files,
            )
        }

        fun fromJson(value: String): BackgroundMediaUploadTask? = runCatching {
            val json = JSONObject(value)
            val files = json.optJSONArray("files")?.let { array ->
                buildList {
                    for (index in 0 until array.length()) {
                        val file = array.optJSONObject(index) ?: continue
                        val field = file.optString("field")
                        val path = file.optString("path")
                        val fileName = file.optString("fileName")
                        val mimeType = file.optString("mimeType")
                        if (field.isNotBlank() && path.isNotBlank() && fileName.isNotBlank() && mimeType.isNotBlank()) {
                            add(BackgroundMediaUploadFile(field, path, fileName, mimeType))
                        }
                    }
                }
            }.orEmpty()
            val taskId = json.optString("taskId")
            val url = json.optString("url")
            if (taskId.isBlank() || url.isBlank() || files.isEmpty()) return@runCatching null
            BackgroundMediaUploadTask(
                taskId = taskId,
                url = url,
                headers = json.optJSONObject("headers").toStringMap(),
                fields = json.optJSONObject("fields").toStringMap(),
                files = files,
            )
        }.getOrNull()
    }
}

private fun Any?.toStringMap(): Map<String, String> = when (this) {
    is Map<*, *> -> entries.mapNotNull { (key, value) ->
        val name = key as? String ?: return@mapNotNull null
        val content = value as? String ?: return@mapNotNull null
        name to content
    }.toMap()
    is JSONObject -> buildMap {
        val iterator = keys()
        while (iterator.hasNext()) {
            val key = iterator.next()
            put(key, optString(key))
        }
    }
    else -> emptyMap()
}

internal object BackgroundMediaUploadStore {
    private const val PREFERENCES = "background_media_upload"
    private const val KEY_PREFIX = "task."
    private const val RETENTION_MS = 24 * 60 * 60 * 1000L

    fun status(context: Context, taskId: String): Map<String, Any> {
        val record = record(context, taskId) ?: return mapOf("state" to "unknown")
        if (System.currentTimeMillis() - record.optLong("updatedAt") > RETENTION_MS) {
            preferences(context).edit().remove(key(taskId)).apply()
            return mapOf("state" to "unknown")
        }
        return mapOf(
            "state" to record.optString("state", "unknown"),
            "statusCode" to record.optInt("statusCode"),
            "body" to record.optString("body"),
            "message" to record.optString("message"),
        )
    }

    fun isCompleted(context: Context, taskId: String): Boolean {
        return status(context, taskId)["state"] == "completed"
    }

    fun markRunning(context: Context, taskId: String) {
        write(context, taskId, "running")
    }

    fun markCompleted(context: Context, taskId: String, statusCode: Int, body: String) {
        write(context, taskId, "completed", statusCode = statusCode, body = body)
    }

    fun markFailed(context: Context, taskId: String, message: String) {
        write(context, taskId, "failed", message = message)
    }

    private fun write(
        context: Context,
        taskId: String,
        state: String,
        statusCode: Int = 0,
        body: String = "",
        message: String = "",
    ) {
        val value = JSONObject()
            .put("state", state)
            .put("statusCode", statusCode)
            .put("body", body)
            .put("message", message)
            .put("updatedAt", System.currentTimeMillis())
        preferences(context).edit().putString(key(taskId), value.toString()).apply()
    }

    private fun record(context: Context, taskId: String): JSONObject? {
        val stored = preferences(context).getString(key(taskId), null) ?: return null
        return runCatching { JSONObject(stored) }.getOrNull()
    }

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    private fun key(taskId: String) = "$KEY_PREFIX$taskId"
}
