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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.ChatBubbleOutline
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.zholdas.data.local.localized
import com.example.zholdas.data.model.ChatMessage
import com.example.zholdas.data.model.ChatSession
import com.example.zholdas.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatRoomScreen(
    session: ChatSession,
    viewModel: ChatViewModel,
    onBackClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val messages by viewModel.currentChatMessages.collectAsState()
    val isRoomLoading by viewModel.isRoomLoading.collectAsState()
    val isAiThinking by viewModel.isAiThinking.collectAsState()
    val roomError by viewModel.roomError.collectAsState()
    val isConnected by viewModel.isRoomConnected.collectAsState()
    var messageText by remember { mutableStateOf("") }
    val listState = rememberLazyListState()

    // Lifecycle: Connect WebSocket on enter & disconnect on exit
    LaunchedEffect(session.id) {
        viewModel.connectToRoom(session.id)
    }

    DisposableEffect(session.id) {
        onDispose {
            viewModel.disconnectFromRoom()
        }
    }

    LaunchedEffect(messages.size, isAiThinking) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(messages.size + if (isAiThinking) 1 else 0)
        }
    }

    val categoryColor = remember(session.categoryColorHex) {
        parseHexColor(session.categoryColorHex)
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = ZholdasBackground,
        topBar = {
            TopAppBar(
                title = {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(categoryColor.copy(alpha = 0.2f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.ChatBubbleOutline,
                                contentDescription = null,
                                tint = categoryColor,
                                modifier = Modifier.size(18.dp)
                            )
                        }

                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = session.title,
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Bold,
                                color = ZholdasTextPrimary,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Text(
                                    text = session.timeLabel,
                                    fontSize = 11.sp,
                                    color = ZholdasTextSecondary
                                )
                                if (session.isCompleted) {
                                    Text(
                                        text = "chat_completed_badge".localized,
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = ZholdasAccent,
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(4.dp))
                                            .background(ZholdasAccent.copy(alpha = 0.15f))
                                            .padding(horizontal = 5.dp, vertical = 2.dp)
                                    )
                                }
                            }
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "back",
                            tint = ZholdasTextPrimary
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = ZholdasSurface
                )
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .background(ZholdasBackground)
        ) {
            if (!isConnected) {
                Text("Подключение к чату…", color = ZholdasTextSecondary, fontSize = 12.sp,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp))
            }
            if (roomError != null) {
                Surface(color = MaterialTheme.colorScheme.errorContainer, modifier = Modifier.fillMaxWidth()) {
                    Text(roomError.orEmpty(), color = MaterialTheme.colorScheme.onErrorContainer,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp))
                }
            }
            // Messages content area
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
            ) {
                if (isRoomLoading && messages.isEmpty()) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = ZholdasAccent)
                    }
                } else if (messages.isEmpty()) {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(32.dp),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(
                            imageVector = Icons.Default.ChatBubbleOutline,
                            contentDescription = null,
                            tint = ZholdasTextTertiary,
                            modifier = Modifier.size(48.dp)
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        Text(
                            text = "Здесь пока пусто",
                            color = ZholdasTextPrimary,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Напишите первое сообщение или упомяните @ai для совета Жорика!",
                            color = ZholdasTextTertiary,
                            fontSize = 13.sp,
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center
                        )
                    }
                } else {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 14.dp),
                        verticalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        items(messages, key = { it.id }) { msg ->
                            EventMessageBubble(message = msg)
                        }

                        if (isAiThinking) {
                            item {
                                AIThinkingBubble()
                            }
                        }
                    }
                }
            }

            // Quick mention @ai chip bar above input
            if (!session.isCompleted) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(ZholdasSurface)
                        .padding(horizontal = 16.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(14.dp))
                            .background(ZholdasElevatedSurface)
                            .border(1.dp, ZholdasAccent.copy(alpha = 0.35f), RoundedCornerShape(14.dp))
                            .clickable {
                                if (!messageText.startsWith("@ai ")) {
                                    messageText = "@ai $messageText"
                                }
                            }
                            .padding(horizontal = 10.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.AutoAwesome,
                            contentDescription = null,
                            tint = ZholdasAccent,
                            modifier = Modifier.size(13.dp)
                        )
                        Text(
                            text = "chat_ai_mention_hint".localized,
                            color = ZholdasTextSecondary,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }

            // Input Area or Read-only completed banner
            if (session.isCompleted) {
                Surface(
                    modifier = Modifier.fillMaxWidth(),
                    color = ZholdasSurface,
                    tonalElevation = 4.dp
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Lock,
                            contentDescription = null,
                            tint = ZholdasTextTertiary,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "chat_readonly_completed".localized,
                            color = ZholdasTextSecondary,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            } else {
                Surface(
                    modifier = Modifier.fillMaxWidth(),
                    color = ZholdasSurface,
                    tonalElevation = 4.dp
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        OutlinedTextField(
                            value = messageText,
                            onValueChange = { messageText = it },
                            modifier = Modifier.weight(1f),
                            placeholder = {
                                Text(
                                    text = "chat_placeholder".localized,
                                    color = ZholdasTextTertiary,
                                    fontSize = 14.sp
                                )
                            },
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedTextColor = ZholdasTextPrimary,
                                unfocusedTextColor = ZholdasTextPrimary,
                                focusedBorderColor = ZholdasAccent,
                                unfocusedBorderColor = ZholdasBorder,
                                focusedContainerColor = ZholdasElevatedSurface,
                                unfocusedContainerColor = ZholdasElevatedSurface
                            ),
                            shape = RoundedCornerShape(22.dp),
                            maxLines = 4
                        )

                        val isSendEnabled = messageText.trim().isNotEmpty()
                        IconButton(
                            onClick = {
                                if (isSendEnabled) {
                                    viewModel.sendRoomMessage(
                                        eventId = session.id,
                                        text = messageText
                                    )
                                    messageText = ""
                                }
                            },
                            enabled = isSendEnabled,
                            modifier = Modifier
                                .size(44.dp)
                                .clip(CircleShape)
                                .background(
                                    if (isSendEnabled) ZholdasAccent else ZholdasAccent.copy(alpha = 0.3f)
                                )
                        ) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.Send,
                                contentDescription = "send",
                                tint = Color.White,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun EventMessageBubble(message: ChatMessage) {
    val isUser = message.isCurrentUser
    val isAI = message.senderID == "ai_zhorik" || message.senderName.contains("Жорик")

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = if (isUser) Alignment.End else Alignment.Start
    ) {
        if (!isUser) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.padding(bottom = 4.dp, start = 4.dp)
            ) {
                if (isAI) {
                    Icon(
                        imageVector = Icons.Default.AutoAwesome,
                        contentDescription = null,
                        tint = ZholdasAccent,
                        modifier = Modifier.size(13.dp)
                    )
                }
                Text(
                    text = message.senderName,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = if (isAI) ZholdasAccent else Color(0xFF48BB78)
                )
            }
        }

        Box(
            modifier = Modifier
                .widthIn(max = 280.dp)
                .clip(
                    RoundedCornerShape(
                        topStart = 18.dp,
                        topEnd = 18.dp,
                        bottomStart = if (isUser) 18.dp else 4.dp,
                        bottomEnd = if (isUser) 4.dp else 18.dp
                    )
                )
                .background(
                    when {
                        isUser -> Brush.linearGradient(listOf(ZholdasAccent, ZholdasAccentDeep))
                        isAI -> Brush.linearGradient(listOf(Color(0xFF2E1A5A), ZholdasElevatedSurface))
                        else -> Brush.linearGradient(listOf(ZholdasElevatedSurface, ZholdasSurface))
                    }
                )
                .border(
                    width = 1.dp,
                    color = when {
                        isUser -> Color.Transparent
                        isAI -> ZholdasAccent.copy(alpha = 0.4f)
                        else -> ZholdasBorder
                    },
                    shape = RoundedCornerShape(
                        topStart = 18.dp,
                        topEnd = 18.dp,
                        bottomStart = if (isUser) 18.dp else 4.dp,
                        bottomEnd = if (isUser) 4.dp else 18.dp
                    )
                )
                .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = message.text,
                    color = ZholdasTextPrimary,
                    fontSize = 14.sp,
                    lineHeight = 20.sp
                )
                Text(
                    text = message.timestamp,
                    color = if (isUser) Color.White.copy(alpha = 0.7f) else ZholdasTextTertiary,
                    fontSize = 10.sp,
                    modifier = Modifier.align(Alignment.End)
                )
            }
        }
    }
}

fun parseHexColor(hexString: String): Color {
    return try {
        val clean = hexString.removePrefix("#")
        val colorInt = clean.toLong(16)
        when (clean.length) {
            6 -> Color(0xFF000000 or colorInt)
            8 -> Color(colorInt)
            else -> ZholdasAccent
        }
    } catch (e: Exception) {
        ZholdasAccent
    }
}
