package com.cypherghost.agentcypher

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import androidx.core.content.ContextCompat
import android.graphics.PixelFormat
import android.graphics.Color
import android.view.Gravity
import android.view.WindowManager
import android.view.View
import android.widget.Button
import android.net.Uri
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.cypherghost.agentcypher/accessibility"
    private val EVENT_CHANNEL = "com.cypherghost.agentcypher/accessibility_events"
    private val WAKE_EVENT_CHANNEL = "com.cypherghost.agentcypher/wake_word_events"
    private val FILES_CHANNEL = "com.cypherghost.agentcypher/files"
    private val PICK_DOCUMENTS_REQUEST = 7001
    private var pendingFileResult: MethodChannel.Result? = null
    private var eventSink: EventChannel.EventSink? = null
    private var wakeEventSink: EventChannel.EventSink? = null
    private var overlayView: View? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    AgentAccessibilityService.eventListener = { eventMap ->
                        runOnUiThread {
                            eventSink?.success(eventMap)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    AgentAccessibilityService.eventListener = null
                }
            }
        )

        registerWakeWordChannel(flutterEngine)
        registerAccessibilityChannel(flutterEngine, this)
        registerFilesChannel(flutterEngine)
    }

    private fun registerFilesChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILES_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickDocuments" -> {
                        if (pendingFileResult != null) {
                            result.error("PICKER_BUSY", "A document picker is already open", null)
                            return@setMethodCallHandler
                        }
                        pendingFileResult = result
                        try {
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                            }
                            startActivityForResult(intent, PICK_DOCUMENTS_REQUEST)
                        } catch (error: Throwable) {
                            pendingFileResult = null
                            result.error(
                                "PICKER_UNAVAILABLE",
                                error.message ?: "Document picker is unavailable",
                                null,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_DOCUMENTS_REQUEST) return

        val result = pendingFileResult
        pendingFileResult = null
        if (result == null) return
        if (resultCode != RESULT_OK || data == null) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }

        try {
            val uris = mutableListOf<Uri>()
            data.clipData?.let { clipData ->
                for (index in 0 until clipData.itemCount) uris.add(clipData.getItemAt(index).uri)
            }
            if (uris.isEmpty()) data.data?.let(uris::add)

            val attachments = uris.distinct().take(5).mapNotNull { copyToCache(it) }
            result.success(attachments)
        } catch (error: Throwable) {
            result.error(
                "PICKER_READ_FAILED",
                error.message ?: "Selected documents could not be read",
                null,
            )
        }
    }

    private fun copyToCache(uri: Uri): Map<String, Any?>? {
        val resolver = contentResolver
        val originalName = resolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
            if (nameIndex >= 0 && cursor.moveToFirst()) cursor.getString(nameIndex) else null
        } ?: uri.lastPathSegment?.substringAfterLast('/') ?: "attachment"
        val safeName = originalName.replace(Regex("[^A-Za-z0-9._-]"), "_").take(120)
        val attachmentDir = File(cacheDir, "attachments").apply { mkdirs() }
        val destination = File(attachmentDir, "${UUID.randomUUID()}_$safeName")
        resolver.openInputStream(uri)?.use { input ->
            destination.outputStream().use { output -> input.copyTo(output) }
        } ?: return null

        val mimeType = resolver.getType(uri) ?: "application/octet-stream"
        return mapOf(
            "id" to destination.nameWithoutExtension,
            "name" to originalName,
            "path" to destination.absolutePath,
            "mimeType" to mimeType,
            "size" to destination.length(),
            "selectedAt" to System.currentTimeMillis().toString(),
        )
    }

    private fun registerWakeWordChannel(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, WAKE_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    wakeEventSink = events
                    BackgroundWakeWordService.eventListener = { eventMap ->
                        runOnUiThread { wakeEventSink?.success(eventMap) }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    wakeEventSink = null
                    BackgroundWakeWordService.eventListener = null
                }
            },
        )
    }

    companion object {
        fun registerAccessibilityChannel(flutterEngine: FlutterEngine, context: android.content.Context) {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.cypherghost.agentcypher/accessibility")
                .setMethodCallHandler { call, result ->
                    android.util.Log.d("AgentCypherKotlin", "Received method call: ${call.method}")
                    when (call.method) {
                        "ping" -> result.success(true)

                        "getWakeWordStatus" -> {
                            result.success(BackgroundWakeWordService.status(context))
                        }

                        "startWakeWordDetection" -> {
                            try {
                                val intent = Intent(context, BackgroundWakeWordService::class.java).apply {
                                    action = BackgroundWakeWordService.ACTION_START
                                }
                                ContextCompat.startForegroundService(context, intent)
                                result.success(true)
                            } catch (error: Throwable) {
                                result.error(
                                    "WAKE_WORD_START_FAILED",
                                    error.message ?: "Could not start wake-word service",
                                    null,
                                )
                            }
                        }

                        "stopWakeWordDetection" -> {
                            context.stopService(Intent(context, BackgroundWakeWordService::class.java))
                            result.success(true)
                        }

                        "pauseWakeWordDetection" -> {
                            context.startService(
                                Intent(context, BackgroundWakeWordService::class.java).apply {
                                    action = BackgroundWakeWordService.ACTION_PAUSE
                                },
                            )
                            result.success(true)
                        }

                        "resumeWakeWordDetection" -> {
                            context.startService(
                                Intent(context, BackgroundWakeWordService::class.java).apply {
                                    action = BackgroundWakeWordService.ACTION_RESUME
                                },
                            )
                            result.success(true)
                        }

                        "logToNative" -> {
                            val msg = call.argument<String>("message") ?: ""
                            android.util.Log.d("AgentCypherDart", msg)
                            result.success(true)
                        }

                        "shareText" -> {
                            val text = call.argument<String>("text") ?: ""
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            context.startActivity(
                                Intent.createChooser(intent, "Share").apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                },
                            )
                            result.success(true)
                        }

                        "isServiceRunning" -> {
                            result.success(AgentAccessibilityService.isRunning())
                        }

                        "checkOverlayPermission" -> {
                            result.success(Settings.canDrawOverlays(context))
                        }

                        "requestOverlayPermission" -> {
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}"))
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(intent)
                            result.success(true)
                        }

                        "showMacroOverlay" -> {
                            // Macro overlay requires an Activity context, so we just ignore or return error if called from background
                            result.error("NOT_SUPPORTED", "Macro overlay not supported from background", null)
                        }

                        "hideMacroOverlay" -> {
                            result.success(true)
                        }

                        "openAccessibilitySettings" -> {
                            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(intent)
                            result.success(true)
                        }

                        "dumpScreen" -> {
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                val nodes = service.dumpScreen()
                                result.success(nodes)
                            }
                        }

                        "takeScreenshot" -> {
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                                    service.takeScreenshot { base64 ->
                                        if (base64 != null) {
                                            result.success(base64)
                                        } else {
                                            result.error("SCREENSHOT_FAILED", "Failed to capture screenshot", null)
                                        }
                                    }
                                } else {
                                    result.error("UNSUPPORTED_VERSION", "Screenshot requires Android 11 (API 30) or higher", null)
                                }
                            }
                        }

                        "clickByText" -> {
                            val text = call.argument<String>("text") ?: ""
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                result.success(service.clickByText(text))
                            }
                        }

                        "clickAt" -> {
                            val x = call.argument<Double>("x")?.toFloat() ?: 0f
                            val y = call.argument<Double>("y")?.toFloat() ?: 0f
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                result.success(service.clickAtCoordinates(x, y))
                            }
                        }

                        "typeText" -> {
                            val text = call.argument<String>("text") ?: ""
                            val hint = call.argument<String>("fieldHint")
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                result.success(service.typeText(text, hint))
                            }
                        }

                        "pressEnter" -> {
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                result.success(service.pressEnter())
                            }
                        }

                        "scroll" -> {
                            val direction = call.argument<String>("direction") ?: "down"
                            val target = call.argument<String>("target")
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                result.success(service.scroll(direction, target))
                            }
                        }

                        "showToast" -> {
                            val message = call.argument<String>("message") ?: ""
                            android.widget.Toast.makeText(context, message, android.widget.Toast.LENGTH_SHORT).show()
                            result.success(true)
                        }

                        "swipe" -> {
                            val startX = call.argument<Double>("startX")?.toFloat() ?: 0f
                            val startY = call.argument<Double>("startY")?.toFloat() ?: 0f
                            val endX = call.argument<Double>("endX")?.toFloat() ?: 0f
                            val endY = call.argument<Double>("endY")?.toFloat() ?: 0f
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                result.success(service.swipe(startX, startY, endX, endY))
                            }
                        }

                        "pressBack" -> {
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                result.success(service.pressBack())
                            }
                        }

                        "pressHome" -> {
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                result.success(service.pressHome())
                            }
                        }

                        "openNotifications" -> {
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                result.success(service.openNotifications())
                            }
                        }

                        "getCurrentPackage" -> {
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                result.success(service.getCurrentPackage())
                            }
                        }

                        "getAccessibilityDiagnostics" -> {
                            val service = AgentAccessibilityService.instance
                            result.success(
                                service?.diagnostics() ?: mapOf(
                                    "service_installed" to true,
                                    "service_enabled" to false,
                                    "service_responding" to false,
                                    "current_package" to "",
                                    "node_count" to 0,
                                    "last_observation_at" to "",
                                ),
                            )
                        }

                        else -> result.notImplemented()
                    }
                }
        }
    }
}

class BackgroundEngineReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: android.content.Context, intent: android.content.Intent) {
        val engine = io.flutter.embedding.engine.FlutterEngineCache
            .getInstance()
            .get("myCachedEngine")
        if (engine == null) {
            android.util.Log.e("AgentCypher", "Background engine myCachedEngine was not found")
            return
        }

        android.util.Log.d(
            "AgentCypher",
            "Registering accessibility channel on myCachedEngine " +
                "(engine=${System.identityHashCode(engine)}, " +
                "dartExecuting=${engine.dartExecutor.isExecutingDart})"
        )
        MainActivity.registerAccessibilityChannel(engine, context.applicationContext)
    }
}
