package com.example.zholdas.ui.screens.chats

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.zholdas.data.local.localized
import com.example.zholdas.data.model.ChatMessage
import com.example.zholdas.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AIChatAssistantScreen(
    viewModel: ChatViewModel,
    onBackClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val messages by viewModel.aiChatMessages.collectAsState()
    val isThinking by viewModel.isAiThinking.collectAsState()
    val aiError by viewModel.aiError.collectAsState()
    var inputQuery by remember { mutableStateOf("") }
    val listState = rememberLazyListState()

    // Auto scroll to bottom on new messages
    LaunchedEffect(messages.size, isThinking) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(messages.size + if (isThinking) 1 else 0)
        }
    }

    val suggestionChips = listOf(
        "ai_chip_weekend".localized,
        "ai_chip_sports".localized,
        "ai_chip_boardgames".localized,
        "ai_chip_zholdas".localized
    )

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
                                modifier = Modifier.size(20.dp)
                            )
                        }

                        Column {
                            Text(
                                text = "chat_ai_assistant_name".localized,
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold,
                                color = ZholdasTextPrimary
                            )
                            Text(
                                text = "chat_ai_badge".localized,
                                fontSize = 11.sp,
                                color = ZholdasAccent
                            )
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "back",
                            tint = Color.White
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
            if (aiError != null) {
                Surface(color = MaterialTheme.colorScheme.errorContainer, modifier = Modifier.fillMaxWidth()) {
                    Text(aiError.orEmpty(), color = MaterialTheme.colorScheme.onErrorContainer,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp))
                }
            }
            // Suggestion Chips
            LazyRow(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 10.dp),
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(suggestionChips) { chipText ->
                    Surface(
                        modifier = Modifier.clickable {
                            viewModel.sendPersonalAIMessage(chipText)
                        },
                        shape = RoundedCornerShape(20.dp),
                        color = ZholdasSurface,
                        border = androidx.compose.foundation.BorderStroke(1.dp, ZholdasAccent.copy(alpha = 0.3f))
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.AutoAwesome,
                                contentDescription = null,
                                tint = ZholdasAccent,
                                modifier = Modifier.size(14.dp)
                            )
                            Text(
                                text = chipText,
                                fontSize = 12.sp,
                                color = ZholdasTextPrimary,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }
            }

            // Messages List
            LazyColumn(
                state = listState,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                items(messages, key = { it.id }) { msg ->
                    AIMessageBubble(message = msg)
                }

                if (isThinking) {
                    item {
                        AIThinkingBubble()
                    }
                }
            }

            // Bottom Input Field
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
                        value = inputQuery,
                        onValueChange = { inputQuery = it },
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
                            unfocusedBorderColor = Color.White.copy(alpha = 0.12f),
                            focusedContainerColor = ZholdasElevatedSurface,
                            unfocusedContainerColor = ZholdasElevatedSurface
                        ),
                        shape = RoundedCornerShape(22.dp),
                        maxLines = 4
                    )

                    val isSendEnabled = inputQuery.trim().isNotEmpty() && !isThinking
                    IconButton(
                        onClick = {
                            if (isSendEnabled) {
                                viewModel.sendPersonalAIMessage(inputQuery)
                                inputQuery = ""
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

@Composable
fun AIMessageBubble(message: ChatMessage) {
    val isUser = message.isCurrentUser

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
                Icon(
                    imageVector = Icons.Default.AutoAwesome,
                    contentDescription = null,
                    tint = ZholdasAccent,
                    modifier = Modifier.size(13.dp)
                )
                Text(
                    text = message.senderName,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = ZholdasAccent
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
                    if (isUser) {
                        Brush.linearGradient(
                            listOf(ZholdasAccent, ZholdasAccentDeep)
                        )
                    } else {
                        Brush.linearGradient(
                            listOf(ZholdasElevatedSurface, ZholdasSurface)
                        )
                    }
                )
                .border(
                    width = 1.dp,
                    color = if (isUser) Color.Transparent else ZholdasBorder,
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

@Composable
fun AIThinkingBubble() {
    Row(
        modifier = Modifier
            .padding(start = 4.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(ZholdasElevatedSurface)
            .border(1.dp, ZholdasBorder, RoundedCornerShape(16.dp))
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        CircularProgressIndicator(
            modifier = Modifier.size(14.dp),
            color = ZholdasAccent,
            strokeWidth = 2.dp
        )
        Text(
            text = "ai_typing".localized,
            fontSize = 12.sp,
            color = ZholdasTextSecondary
        )
    }
}
