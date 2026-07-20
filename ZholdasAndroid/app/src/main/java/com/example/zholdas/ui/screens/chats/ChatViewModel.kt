package com.example.zholdas.ui.screens.chats

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.zholdas.data.local.TokenManager
import com.example.zholdas.data.local.localized
import com.example.zholdas.data.model.AIChatMessageItem
import com.example.zholdas.data.model.AIChatRequest
import com.example.zholdas.data.model.ChatMessage
import com.example.zholdas.data.model.ChatSession
import com.example.zholdas.data.model.SendMessageRequest
import com.example.zholdas.data.remote.APIClient
import com.example.zholdas.data.remote.ChatWebSocketManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class ChatViewModel(private val apiClient: APIClient, private val tokenManager: TokenManager) : ViewModel() {
    companion object {
        private const val TAG = "ChatViewModel"
        const val AI_SESSION_ID = 999
        fun formatCurrentTime() = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
        fun formatTimeFromIsoOrCurrent(value: String): String = try {
            if (value.isBlank()) formatCurrentTime()
            else if (value.length <= 5 && value.contains(":")) value
            else SimpleDateFormat("HH:mm", Locale.getDefault()).format(
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault()).parse(value) ?: Date()
            )
        } catch (_: Exception) { formatCurrentTime() }
    }

    private val _chatSessions = MutableStateFlow<List<ChatSession>>(emptyList())
    val chatSessions = _chatSessions.asStateFlow()
    private val _searchQuery = MutableStateFlow("")
    val searchQuery = _searchQuery.asStateFlow()
    private val _isLoading = MutableStateFlow(false)
    val isLoading = _isLoading.asStateFlow()
    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage = _errorMessage.asStateFlow()
    private val _unreadCountMap = MutableStateFlow<Map<Int, Int>>(emptyMap())
    val unreadCountMap = _unreadCountMap.asStateFlow()
    private val _currentChatMessages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val currentChatMessages = _currentChatMessages.asStateFlow()
    private val _isRoomLoading = MutableStateFlow(false)
    val isRoomLoading = _isRoomLoading.asStateFlow()
    private val _roomError = MutableStateFlow<String?>(null)
    val roomError = _roomError.asStateFlow()
    private val _isRoomConnected = MutableStateFlow(false)
    val isRoomConnected = _isRoomConnected.asStateFlow()
    private val _aiError = MutableStateFlow<String?>(null)
    val aiError = _aiError.asStateFlow()
    private val _aiChatMessages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val aiChatMessages = _aiChatMessages.asStateFlow()
    private val _isAiThinking = MutableStateFlow(false)
    val isAiThinking = _isAiThinking.asStateFlow()
    private var webSocketManager: ChatWebSocketManager? = null

    init { fetchChatSessions() }
    fun setSearchQuery(query: String) { _searchQuery.value = query }

    fun fetchChatSessions() = viewModelScope.launch {
        _isLoading.value = true
        _errorMessage.value = null
        try {
            _chatSessions.value = listOf(aiSession()) + apiClient.apiService.getChatSessions()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load chats", e)
            _chatSessions.value = emptyList()
            _errorMessage.value = "chat_load_error".localized
        } finally { _isLoading.value = false }
    }

    private fun aiSession() = ChatSession(
        id = AI_SESSION_ID, title = "chat_ai_assistant_name".localized, category = "ai", timeLabel = "chat_ai_active".localized,
        lastMessage = "chat_ai_assistant_welcome".localized, lastMessageSender = "chat_ai_assistant_name".localized,
        lastMessageTime = "", isCompleted = false, categoryIcon = "sparkles", categoryColorHex = "#7C5CFF"
    )

    fun markSessionRead(id: Int) { _unreadCountMap.update { it - id } }

    fun connectToRoom(eventId: Int) {
        disconnectFromRoom()
        markSessionRead(eventId)
        loadRoomHistory(eventId)
        ChatWebSocketManager(eventId, tokenManager, apiClient.backendBaseUrl.replaceFirst("http", "ws")).also { ws ->
            webSocketManager = ws
            ws.onConnectionStateChanged = { _isRoomConnected.value = it }
            ws.onMessageReceived = { response ->
                val message = response.toChatMessage()
                _currentChatMessages.update { list -> if (list.none { it.dbID == message.dbID }) list + message else list }
            }
            ws.connect()
        }
    }

    fun disconnectFromRoom() {
        webSocketManager?.disconnect()
        webSocketManager = null
        _isRoomConnected.value = false
    }

    private fun loadRoomHistory(eventId: Int) = viewModelScope.launch {
        _isRoomLoading.value = true
        _roomError.value = null
        _currentChatMessages.value = emptyList()
        try { _currentChatMessages.value = apiClient.apiService.getEventMessages(eventId).map { it.toChatMessage() } }
        catch (e: Exception) {
            Log.w(TAG, "Failed to load room history", e)
            _roomError.value = "chat_messages_load_error".localized
        } finally { _isRoomLoading.value = false }
    }

    private fun com.example.zholdas.data.model.EventMessageResponse.toChatMessage() = ChatMessage(
        id = UUID.randomUUID().toString(), senderName = senderName.ifEmpty { senderUsername },
        senderAvatarURL = senderAvatarURL, text = text, timestamp = formatTimeFromIsoOrCurrent(createdAt),
        isCurrentUser = false, dbID = id, senderID = senderID
    )

    fun sendRoomMessage(eventId: Int, text: String, currentUserId: String = "me", currentUserName: String = "chat_prefix_you".localized.removeSuffix(": "), avatarUrl: String? = null) {
        val clean = text.trim(); if (clean.isEmpty()) return
        val localId = UUID.randomUUID().toString()
        _currentChatMessages.update { it + ChatMessage(localId, currentUserName, avatarUrl, clean, formatCurrentTime(), true, senderID = currentUserId) }
        viewModelScope.launch {
            try {
                val sent = apiClient.apiService.sendEventMessage(eventId, SendMessageRequest(clean))
                _currentChatMessages.update { list -> list.map { if (it.id == localId) it.copy(dbID = sent.id, timestamp = formatTimeFromIsoOrCurrent(sent.createdAt)) else it } }
                if (clean.contains("@ai", true) || clean.contains("@жорик", true) || clean.contains("@zhorik", true)) requestRoomAI(clean)
            } catch (e: Exception) {
                _currentChatMessages.update { list -> list.filterNot { it.id == localId } }
                _roomError.value = "chat_send_error".localized
            }
        }
    }

    private fun requestRoomAI(text: String) = viewModelScope.launch {
        _isAiThinking.value = true
        try {
            val prompt = text.replace("@ai", "", true).replace("@жорик", "", true).replace("@zhorik", "", true).trim()
            val reply = apiClient.apiService.chatWithAI(AIChatRequest(prompt)).reply
            _currentChatMessages.update { it + ChatMessage(UUID.randomUUID().toString(), "chat_ai_assistant_name".localized, text = reply, timestamp = formatCurrentTime(), isCurrentUser = false, senderID = "ai_zhorik") }
        } catch (e: Exception) { _roomError.value = "chat_ai_unavailable".localized }
        finally { _isAiThinking.value = false }
    }

    fun sendPersonalAIMessage(text: String) {
        val clean = text.trim(); if (clean.isEmpty()) return
        val user = ChatMessage(UUID.randomUUID().toString(), "chat_prefix_you".localized.removeSuffix(": "), text = clean, timestamp = formatCurrentTime(), isCurrentUser = true)
        _aiChatMessages.update { it + user }; _isAiThinking.value = true; _aiError.value = null
        viewModelScope.launch {
            try {
                val history = _aiChatMessages.value.dropLast(1).map { AIChatMessageItem(if (it.isCurrentUser) "user" else "assistant", it.text) }
                val reply = apiClient.apiService.chatWithAI(AIChatRequest(clean, history)).reply
                _aiChatMessages.update { it + ChatMessage(UUID.randomUUID().toString(), "chat_ai_assistant_name".localized, text = reply, timestamp = formatCurrentTime(), isCurrentUser = false) }
            } catch (e: Exception) {
                _aiChatMessages.update { it.filterNot { message -> message.id == user.id } }
                _aiError.value = "chat_ai_response_error".localized
            } finally { _isAiThinking.value = false }
        }
    }

    override fun onCleared() { disconnectFromRoom(); super.onCleared() }

    class Factory(private val apiClient: APIClient, private val tokenManager: TokenManager) : ViewModelProvider.Factory {
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            @Suppress("UNCHECKED_CAST") return ChatViewModel(apiClient, tokenManager) as T
        }
    }
}
