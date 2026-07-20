package com.example.zholdas.ui.screens.chats

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.ChatBubbleOutline
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.automirrored.filled.DirectionsRun
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.filled.LocalMovies
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.zholdas.ZholdasApplication
import com.example.zholdas.data.local.localized
import com.example.zholdas.data.model.ChatSession
import com.example.zholdas.theme.*

@Composable
fun ChatListScreen(
    modifier: Modifier = Modifier,
    onAIChatClick: (() -> Unit)? = null,
    onChatClick: ((ChatSession) -> Unit)? = null
) {
    val context = LocalContext.current
    val app = context.applicationContext as ZholdasApplication
    val viewModel: ChatViewModel = viewModel(
        factory = ChatViewModel.Factory(app.container.apiClient, app.container.tokenManager)
    )

    val sessions by viewModel.chatSessions.collectAsState()
    val searchQuery by viewModel.searchQuery.collectAsState()
    val unreadMap by viewModel.unreadCountMap.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()

    var selectedAIChat by remember { mutableStateOf(false) }
    var selectedRoomSession by remember { mutableStateOf<ChatSession?>(null) }

    // Internal navigation when embedded directly in host
    if (selectedAIChat && onAIChatClick == null) {
        AIChatAssistantScreen(
            viewModel = viewModel,
            onBackClick = { selectedAIChat = false }
        )
        return
    }

    if (selectedRoomSession != null && onChatClick == null) {
        ChatRoomScreen(
            session = selectedRoomSession!!,
            viewModel = viewModel,
            onBackClick = { selectedRoomSession = null }
        )
        return
    }

    val filteredSessions = remember(sessions, searchQuery) {
        if (searchQuery.isBlank()) {
            sessions
        } else {
            sessions.filter {
                it.title.contains(searchQuery, ignoreCase = true) ||
                        it.lastMessage.contains(searchQuery, ignoreCase = true)
            }
        }
    }

    val pinnedAiSession = filteredSessions.firstOrNull { it.id == ChatViewModel.AI_SESSION_ID }
    val eventSessions = filteredSessions.filter { it.id != ChatViewModel.AI_SESSION_ID }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(ZholdasBackground)
    ) {
        // Header
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 16.dp)
        ) {
            Text(
                text = "tab_chats".localized,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = ZholdasTextPrimary
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "${sessions.size} чатов · Алматы",
                fontSize = 13.sp,
                color = ZholdasTextSecondary
            )

            Spacer(modifier = Modifier.height(14.dp))

            // Search Bar
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { viewModel.setSearchQuery(it) },
                modifier = Modifier.fillMaxWidth(),
                placeholder = {
                    Text(
                        text = "chats_search_placeholder".localized,
                        color = ZholdasTextTertiary,
                        fontSize = 14.sp
                    )
                },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = "search",
                        tint = ZholdasTextSecondary,
                        modifier = Modifier.size(20.dp)
                    )
                },
                trailingIcon = {
                    if (searchQuery.isNotEmpty()) {
                        IconButton(onClick = { viewModel.setSearchQuery("") }) {
                            Icon(
                                imageVector = Icons.Default.Clear,
                                contentDescription = "clear",
                                tint = ZholdasTextSecondary,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = ZholdasTextPrimary,
                    unfocusedTextColor = ZholdasTextPrimary,
                    focusedBorderColor = ZholdasAccent,
                    unfocusedBorderColor = ZholdasBorder,
                    focusedContainerColor = ZholdasSurface,
                    unfocusedContainerColor = ZholdasSurface
                ),
                shape = RoundedCornerShape(14.dp),
                singleLine = true
            )
        }

        // Sessions List
        if (errorMessage != null) {
            Surface(color = MaterialTheme.colorScheme.errorContainer, modifier = Modifier.fillMaxWidth()) {
                Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(errorMessage.orEmpty(), modifier = Modifier.weight(1f), color = MaterialTheme.colorScheme.onErrorContainer)
                    TextButton(onClick = viewModel::fetchChatSessions) { Text("Повторить") }
                }
            }
        }
        if (isLoading && sessions.isEmpty()) {
            LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
        }

        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Pinned AI Assistant Chat
            if (pinnedAiSession != null) {
                item {
                    Text(
                        text = "chat_pinned_section".localized,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = ZholdasAccent,
                        modifier = Modifier.padding(bottom = 6.dp)
                    )

                    AIChatAssistantRow(
                        session = pinnedAiSession,
                        onClick = {
                            if (onAIChatClick != null) {
                                onAIChatClick()
                            } else {
                                selectedAIChat = true
                            }
                        }
                    )
                }
            }

            // Event Group Chats Section
            if (eventSessions.isNotEmpty()) {
                item {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "chat_events_section".localized,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        color = ZholdasTextSecondary,
                        modifier = Modifier.padding(bottom = 6.dp)
                    )
                }

                items(eventSessions, key = { it.id }) { session ->
                    val unread = unreadMap[session.id] ?: 0
                    EventChatRow(
                        session = session,
                        unreadCount = unread,
                        onClick = {
                            if (onChatClick != null) {
                                onChatClick(session)
                            } else {
                                selectedRoomSession = session
                            }
                        }
                    )
                }
            } else if (pinnedAiSession == null) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 40.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "Чаты не найдены",
                            color = ZholdasTextTertiary,
                            fontSize = 14.sp
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun AIChatAssistantRow(
    session: ChatSession,
    onClick: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(18.dp),
        color = ZholdasSurface,
        border = androidx.compose.foundation.BorderStroke(
            width = 1.dp,
            brush = Brush.linearGradient(
                listOf(ZholdasAccent, ZholdasAccentDeep)
            )
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Gradient AI Icon
            Box(
                modifier = Modifier
                    .size(52.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.linearGradient(
                            listOf(ZholdasAccent, ZholdasAccentDeep)
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.AutoAwesome,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(26.dp)
                )
            }

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "chat_ai_assistant_name".localized,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = ZholdasTextPrimary
                    )

                    Surface(
                        shape = RoundedCornerShape(8.dp),
                        color = ZholdasAccent.copy(alpha = 0.15f)
                    ) {
                        Text(
                            text = "AI",
                            color = ZholdasAccent,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }

                Text(
                    text = session.lastMessage.ifBlank { "chat_ai_assistant_welcome".localized },
                    fontSize = 13.sp,
                    color = ZholdasTextSecondary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

@Composable
fun EventChatRow(
    session: ChatSession,
    unreadCount: Int,
    onClick: () -> Unit
) {
    val categoryColor = remember(session.categoryColorHex) {
        parseHexColor(session.categoryColorHex)
    }

    val categoryIcon = remember(session.category) {
        getCategoryIconVector(session.category)
    }

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(18.dp),
        color = ZholdasSurface,
        border = androidx.compose.foundation.BorderStroke(1.dp, ZholdasBorder)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Category Icon
            Box(
                modifier = Modifier
                    .size(52.dp)
                    .clip(CircleShape)
                    .background(categoryColor.copy(alpha = 0.16f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = categoryIcon,
                    contentDescription = null,
                    tint = categoryColor,
                    modifier = Modifier.size(24.dp)
                )
            }

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = session.title,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        color = ZholdasTextPrimary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f)
                    )

                    Spacer(modifier = Modifier.width(8.dp))

                    Text(
                        text = session.timeLabel,
                        fontSize = 11.sp,
                        color = ZholdasTextTertiary
                    )
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = if (session.lastMessageSender.isNotBlank()) {
                            "${session.lastMessageSender}: ${session.lastMessage}"
                        } else {
                            session.lastMessage
                        },
                        fontSize = 13.sp,
                        color = if (unreadCount > 0) ZholdasTextPrimary else ZholdasTextSecondary,
                        fontWeight = if (unreadCount > 0) FontWeight.Medium else FontWeight.Normal,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f)
                    )

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        if (session.isCompleted) {
                            Surface(
                                shape = RoundedCornerShape(6.dp),
                                color = ZholdasAccent.copy(alpha = 0.15f)
                            ) {
                                Text(
                                    text = "chat_completed_badge".localized,
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = ZholdasAccent,
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                )
                            }
                        }

                        if (unreadCount > 0) {
                            Box(
                                modifier = Modifier
                                    .clip(CircleShape)
                                    .background(ZholdasDanger)
                                    .padding(horizontal = 7.dp, vertical = 2.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = unreadCount.toString(),
                                    color = Color.White,
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

fun getCategoryIconVector(category: String): ImageVector {
    return when (category.lowercase()) {
        "running", "спорт", "sport", "бег" -> Icons.AutoMirrored.Filled.DirectionsRun
        "boardgames", "настолки", "игры" -> Icons.Default.Extension
        "cinema", "кино", "movies" -> Icons.Default.LocalMovies
        "walk", "прогулка", "горы" -> Icons.AutoMirrored.Filled.DirectionsWalk
        else -> Icons.Default.ChatBubbleOutline
    }
}
