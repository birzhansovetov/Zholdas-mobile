package com.example.zholdas.data.remote

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.example.zholdas.data.local.TokenManager
import com.example.zholdas.data.model.EventMessageResponse
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import okhttp3.*
import java.util.concurrent.TimeUnit

class ChatWebSocketManager(
    private val eventID: Int,
    private val tokenManager: TokenManager,
    private val backendWsUrl: String
) {
    companion object {
        private const val TAG = "ChatWSManager"
    }

    private var client: OkHttpClient? = null
    private var webSocket: WebSocket? = null
    private var isClosed = false
    private var reconnectScheduled = false
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val handler = Handler(Looper.getMainLooper())
    private val json = Json { ignoreUnknownKeys = true }

    var onMessageReceived: ((EventMessageResponse) -> Unit)? = null
    var onConnectionStateChanged: ((Boolean) -> Unit)? = null

    fun connect() {
        isClosed = false
        reconnectScheduled = false
        scope.launch {
            val token = tokenManager.accessToken.firstOrNull()
            if (token.isNullOrBlank()) {
                Log.e(TAG, "Cannot connect to websocket: Access token is missing.")
                notifyStateChanged(false)
                return@launch
            }
            openSocket(token)
        }
    }

    private fun openSocket(token: String) {
        webSocket?.cancel()
        client?.dispatcher?.executorService?.shutdown()
        val urlString = "$backendWsUrl/events/$eventID/ws?token=$token"

        client = OkHttpClient.Builder()
            .readTimeout(0, TimeUnit.MILLISECONDS) // Keep connection alive indefinitely
            .build()

        val request = Request.Builder()
            .url(urlString)
            .build()

        webSocket = client?.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "WebSocket Opened for event $eventID")
                isClosed = false
                notifyStateChanged(true)
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                try {
                    val message = json.decodeFromString<EventMessageResponse>(text)
                    handler.post {
                        onMessageReceived?.invoke(message)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "WebSocket message could not be parsed")
                }
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "WebSocket closing with code $code")
                webSocket.close(1000, null)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "WebSocket closed with code $code")
                notifyStateChanged(false)
                handleDisconnect()
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "WebSocket connection failed")
                notifyStateChanged(false)
                handleDisconnect()
            }
        })
    }

    fun disconnect() {
        isClosed = true
        reconnectScheduled = false
        handler.removeCallbacksAndMessages(null)
        onMessageReceived = null
        onConnectionStateChanged = null
        webSocket?.close(1000, "User disconnect")
        webSocket = null
        client?.dispatcher?.executorService?.shutdown()
        client = null
        scope.cancel()
        Log.d(TAG, "WebSocket Disconnected manually from event $eventID")
    }

    private fun handleDisconnect() {
        if (isClosed || reconnectScheduled) return
        reconnectScheduled = true
        // Reconnect after 3 seconds
        handler.postDelayed({
            if (!isClosed) {
                reconnectScheduled = false
                Log.d(TAG, "WebSocket Reconnecting...")
                connect()
            }
        }, 3000)
    }

    private fun notifyStateChanged(isConnected: Boolean) {
        handler.post {
            onConnectionStateChanged?.invoke(isConnected)
        }
    }
}
