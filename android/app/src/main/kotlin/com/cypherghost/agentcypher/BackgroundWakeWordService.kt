package com.cypherghost.agentcypher

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import java.util.Locale

/**
 * Foreground, built-in speech-recognition wake-word bridge.
 *
 * This is deliberately a small native bridge: it reports recognition events to
 * Flutter and does not claim a dedicated always-on keyword model. The service
 * remains truthful when recognition is unavailable or permission is missing.
 */
class BackgroundWakeWordService : Service() {
    companion object {
        const val ACTION_START = "com.cypherghost.agentcypher.wake.START"
        const val ACTION_STOP = "com.cypherghost.agentcypher.wake.STOP"
        const val ACTION_PAUSE = "com.cypherghost.agentcypher.wake.PAUSE"
        const val ACTION_RESUME = "com.cypherghost.agentcypher.wake.RESUME"

        private const val CHANNEL_ID = "agent_cypher_wake_word"
        private const val NOTIFICATION_ID = 4107
        private const val MAX_RESTART_DELAY_MS = 4000L

        @Volatile
        var eventListener: ((Map<String, Any>) -> Unit)? = null

        @Volatile
        private var serviceRunning = false

        @Volatile
        private var servicePaused = false

        @Volatile
        private var lastError: String? = null

        fun status(context: Context): Map<String, Any?> {
            val available = runCatching {
                SpeechRecognizer.isRecognitionAvailable(context)
            }.getOrDefault(false)
            return mapOf(
                "available" to available,
                "running" to serviceRunning,
                "paused" to servicePaused,
                "detector" to "android_builtin_speech_recognizer",
                "wake_word_supported" to available,
                "last_error" to lastError,
            )
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private var restartDelayMs = 500L

    private val recognitionListener = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {
            emit("listening", mapOf("state" to "ready"))
        }

        override fun onBeginningOfSpeech() {
            emit("listening", mapOf("state" to "began"))
        }

        override fun onRmsChanged(rmsdB: Float) = Unit

        override fun onBufferReceived(buffer: ByteArray?) = Unit

        override fun onEndOfSpeech() {
            emit("listening", mapOf("state" to "ended"))
        }

        override fun onError(error: Int) {
            lastError = error.toString()
            emit("error", mapOf("code" to error))
            scheduleRestart()
        }

        override fun onResults(results: Bundle?) {
            val matches = results
                ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                .orEmpty()
            val transcript = matches.firstOrNull().orEmpty().trim()
            if (transcript.isNotEmpty()) {
                emit("transcript", mapOf("text" to transcript))
                if (containsWakePhrase(transcript)) {
                    emit("wake_word", mapOf("text" to transcript, "phrase" to "hey cypher"))
                }
            }
            scheduleRestart()
        }

        override fun onPartialResults(partialResults: Bundle?) {
            val transcript = partialResults
                ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.firstOrNull()
                .orEmpty()
                .trim()
            if (transcript.isNotEmpty() && containsWakePhrase(transcript)) {
                emit("wake_word", mapOf("text" to transcript, "partial" to true, "phrase" to "hey cypher"))
            }
        }

        override fun onEvent(eventType: Int, params: Bundle?) = Unit
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForegroundCompat()
        serviceRunning = true
        emit("status", mapOf("running" to true))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> stopSelf()
            ACTION_PAUSE -> pauseRecognition()
            ACTION_RESUME -> resumeRecognition()
            ACTION_START, null -> startRecognition()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        serviceRunning = false
        servicePaused = false
        mainHandler.removeCallbacksAndMessages(null)
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
        emit("status", mapOf("running" to false))
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startRecognition() {
        servicePaused = false
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            lastError = "Speech recognition unavailable"
            emit("unavailable", mapOf("reason" to "speech_recognition_unavailable"))
            return
        }
        if (recognizer == null) {
            recognizer = SpeechRecognizer.createSpeechRecognizer(this).also {
                it.setRecognitionListener(recognitionListener)
            }
        }
        restartDelayMs = 500L
        scheduleRestart(0L)
    }

    private fun pauseRecognition() {
        servicePaused = true
        mainHandler.removeCallbacksAndMessages(null)
        recognizer?.cancel()
        emit("status", mapOf("paused" to true))
    }

    private fun resumeRecognition() {
        servicePaused = false
        emit("status", mapOf("paused" to false))
        startRecognition()
    }

    private fun scheduleRestart(delayMs: Long = restartDelayMs) {
        if (!serviceRunning || servicePaused) return
        mainHandler.removeCallbacksAndMessages(null)
        mainHandler.postDelayed({
            if (!serviceRunning || servicePaused) return@postDelayed
            runCatching {
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                }
                recognizer?.startListening(intent)
            }.onFailure {
                lastError = it.message ?: "Could not start speech recognition"
                emit("error", mapOf("message" to lastError.orEmpty()))
                restartDelayMs = (restartDelayMs * 2).coerceAtMost(MAX_RESTART_DELAY_MS)
                scheduleRestart(restartDelayMs)
            }
        }, delayMs)
        restartDelayMs = (restartDelayMs * 2).coerceAtMost(MAX_RESTART_DELAY_MS)
    }

    private fun containsWakePhrase(transcript: String): Boolean {
        return transcript.lowercase(Locale.getDefault())
            .replace(Regex("[^a-z0-9 ]"), " ")
            .replace(Regex("\\s+"), " ")
            .contains("hey cypher")
    }

    private fun emit(type: String, values: Map<String, Any>) {
        val payload = mutableMapOf<String, Any>("type" to type)
        payload.putAll(values)
        eventListener?.invoke(payload)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Agent Cypher wake word",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shows when background speech recognition is active"
                setSound(null, null)
            },
        )
    }

    private fun startForegroundCompat() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or pendingIntentImmutableFlag(),
            )
        }
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("Agent Cypher listening")
            .setContentText("Built-in speech recognition is active")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .apply { if (pendingIntent != null) setContentIntent(pendingIntent) }
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun pendingIntentImmutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
    }
}
