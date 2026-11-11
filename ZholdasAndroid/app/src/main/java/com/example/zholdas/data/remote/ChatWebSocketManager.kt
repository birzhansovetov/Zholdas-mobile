package com.example.zholdas.data.remote

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.example.zholdas.data.local.TokenManager
import com.example.zholdas.data.model.EventMessageResponse
import kotlinx.coroutines.CancellationException
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
    private val backendWsUrl: String,
    private val refreshSession: suspend () -> Boolean = { false }
) {
    companion object {
        private const val TAG = "ChatWSManager"
        private const val INITIAL_RECONNECT_DELAY_MS = 3000L
        private const val MAX_RECONNECT_DELAY_MS = 60000L
    }

    private val client: OkHttpClient = OkHttpClient.Builder()
        .pingInterval(25, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()

    private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var webSocket: WebSocket? = null
    private var isClosed = false
    private var reconnectScheduled = false
    private var reconnectDelayMs = INITIAL_RECONNECT_DELAY_MS
    private var hasConnectedBefore = false
    private var authRefreshAttempted = false
    private val handler = Handler(Looper.getMainLooper())
    private val json = Json { ignoreUnknownKeys = true }

    var onMessageReceived: ((EventMessageResponse) -> Unit)? = null
    var onConnectionStateChanged: ((Boolean) -> Unit)? = null
    var onReconnected: (() -> Unit)? = null

    fun connect() {
        if (isClosed) return
        isClosed = false
        reconnectScheduled = false
        val token = tokenManager.currentTokens()?.accessToken
        if (token.isNullOrBlank()) {
            Log.e(TAG, "Cannot connect to websocket: Access token is missing.")
            notifyStateChanged(false)
            return
        }
        openSocket(token)
    }

    private fun openSocket(token: String) {
        webSocket?.cancel()
        val urlString = "$backendWsUrl/events/$eventID/ws?token=$token"

        val request = Request.Builder()
            .url(urlString)
            .build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                if (isClosed || this@ChatWebSocketManager.webSocket !== webSocket) return
                Log.d(TAG, "WebSocket Opened for event $eventID")
                authRefreshAttempted = false
                reconnectDelayMs = INITIAL_RECONNECT_DELAY_MS
                notifyStateChanged(true)
                if (hasConnectedBefore) {
                    handler.post {
                        onReconnected?.invoke()
                    }
                } else {
                    hasConnectedBefore = true
                }
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                if (isClosed || this@ChatWebSocketManager.webSocket !== webSocket) return
                try {
                    val message = json.decodeFromString<EventMessageResponse>(text)
                    handler.post {
                        onMessageReceived?.invoke(message)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "WebSocket message could not be parsed", e)
                }
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                if (isClosed || this@ChatWebSocketManager.webSocket !== webSocket) return
                Log.d(TAG, "WebSocket closing with code $code")
                webSocket.close(1000, null)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                if (isClosed || this@ChatWebSocketManager.webSocket !== webSocket) return
                Log.d(TAG, "WebSocket closed with code $code")
                notifyStateChanged(false)
                handleDisconnect()
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                if (isClosed || this@ChatWebSocketManager.webSocket !== webSocket) return
                Log.e(TAG, "WebSocket connection failed: ${t.message}, response code: ${response?.code}")
                notifyStateChanged(false)
                val code = response?.code
                if (code == 403) {
                    Log.w(TAG, "WebSocket handshake rejected with code 403, aborting reconnect.")
                    return
                }
                if (code == 401) {
                    if (!authRefreshAttempted) {
                        authRefreshAttempted = true
                        coroutineScope.launch {
                            val refreshed = try {
                                refreshSession()
                            } catch (e: Exception) {
                                if (e is CancellationException) throw e
                                Log.e(TAG, "Failed to refresh session for WebSocket", e)
                                false
                            }
                            if (refreshed && !isClosed) {
                                Log.d(TAG, "Session refreshed, reconnecting WebSocket...")
                                connect()
                            } else {
                                Log.w(TAG, "Session refresh failed or manager is closed, aborting reconnect.")
                                notifyStateChanged(false)
                            }
                        }
                    } else {
                        Log.w(TAG, "WebSocket 401 received again after refresh attempt, aborting reconnect.")
                    }
                    return
                }
                handleDisconnect()
            }
        })
    }

    fun disconnect() {
        isClosed = true
        reconnectScheduled = false
        coroutineScope.cancel()
        handler.removeCallbacksAndMessages(null)
        onMessageReceived = null
        onConnectionStateChanged = null
        onReconnected = null
        webSocket?.close(1000, "User disconnect")
        webSocket = null
        client.dispatcher.executorService.shutdown()
        Log.d(TAG, "WebSocket Disconnected manually from event $eventID")
    }

    private fun handleDisconnect() {
        if (isClosed || reconnectScheduled) return
        reconnectScheduled = true
        val delay = reconnectDelayMs
        reconnectDelayMs = (reconnectDelayMs * 2).coerceAtMost(MAX_RECONNECT_DELAY_MS)
        handler.postDelayed({
            if (isClosed) {
                reconnectScheduled = false
                return@postDelayed
            }
            reconnectScheduled = false
            Log.d(TAG, "WebSocket Reconnecting after ${delay / 1000}s...")
            connect()
        }, delay)
    }

    private fun notifyStateChanged(isConnected: Boolean) {
        handler.post {
            onConnectionStateChanged?.invoke(isConnected)
        }
    }
}
