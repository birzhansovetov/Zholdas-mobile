package com.example.zholdas.ui.screens.activity

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
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.zholdas.data.local.localized
import com.example.zholdas.data.model.NotificationItem
import com.example.zholdas.theme.*
import com.example.zholdas.ui.AuthViewModel
import com.example.zholdas.ui.components.ModernCard
import kotlinx.coroutines.launch

@Composable
fun ActivityScreen(
    authViewModel: AuthViewModel? = null,
    modifier: Modifier = Modifier
) {
    val coroutineScope = rememberCoroutineScope()

    var selectedTabIndex by remember { mutableStateOf(0) }
    var notifications by remember { mutableStateOf<List<NotificationItem>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        isLoading = true
        if (authViewModel != null) {
            notifications = authViewModel.fetchNotificationsList()
            authViewModel.markAllNotificationsRead()
        }
        isLoading = false
    }

    val filteredNotifications = remember(selectedTabIndex, notifications) {
        if (selectedTabIndex == 1) {
            emptyList()
        } else {
            notifications
        }
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = ZholdasBackground
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // Header
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 20.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = "tab_activity".localized,
                    color = ZholdasTextPrimary,
                    fontSize = 32.sp,
                    fontWeight = FontWeight.ExtraBold
                )
                Text(
                    text = "act_all_community".localized,
                    color = ZholdasTextSecondary,
                    fontSize = 15.sp
                )
            }

            // Custom Segmented Pill Selector ("Все" / "Друзья")
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(ZholdasSurface)
                    .border(1.dp, ZholdasBorder, RoundedCornerShape(14.dp))
                    .padding(4.dp),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                val tabTitles = listOf("act_tab_all".localized, "act_tab_friends".localized)
                tabTitles.forEachIndexed { index, title ->
                    val isSelected = selectedTabIndex == index
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (isSelected) ZholdasAccent else Color.Transparent)
                            .clickable { selectedTabIndex = index }
                            .padding(vertical = 10.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = title,
                            color = if (isSelected) Color.White else ZholdasTextSecondary,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                            fontSize = 14.sp
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Main Content Area
            if (isLoading && notifications.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = ZholdasAccent)
                }
            } else if (filteredNotifications.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    EmptyActivityCard(selectedTabIndex = selectedTabIndex)
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(filteredNotifications) { item ->
                        NotificationItemRow(item = item)
                    }
                }
            }
        }
    }
}

@Composable
private fun EmptyActivityCard(selectedTabIndex: Int) {
    val isFriendsTab = selectedTabIndex == 1

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(ZholdasSurface.copy(alpha = 0.75f))
            .border(1.dp, ZholdasBorder, RoundedCornerShape(16.dp))
            .padding(horizontal = 24.dp, vertical = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Box(
            modifier = Modifier
                .size(80.dp)
                .clip(CircleShape)
                .background(
                    brush = Brush.linearGradient(
                        colors = listOf(
                            ZholdasAccent.copy(alpha = 0.35f),
                            Color(0xFF261440)
                        )
                    )
                )
                .border(1.dp, ZholdasAccent.copy(alpha = 0.3f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.AutoAwesome,
                contentDescription = null,
                tint = ZholdasAccent,
                modifier = Modifier.size(32.dp)
            )
        }

        Text(
            text = if (isFriendsTab) "act_no_friends".localized else "act_no_notifications".localized,
            color = ZholdasTextPrimary,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center
        )

        Text(
            text = if (isFriendsTab) "act_no_friends_hint".localized else "act_no_notifications_hint".localized,
            color = ZholdasTextSecondary,
            fontSize = 14.sp,
            textAlign = TextAlign.Center,
            lineHeight = 20.sp
        )
    }
}

@Composable
private fun NotificationItemRow(item: NotificationItem) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(ZholdasSurface)
            .border(1.dp, ZholdasBorder, RoundedCornerShape(14.dp))
            .padding(14.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // Actor Avatar with Badge Icon
        Box {
            Box(
                modifier = Modifier
                    .size(46.dp)
                    .clip(CircleShape)
                    .background(ZholdasElevatedSurface),
                contentAlignment = Alignment.Center
            ) {
                val initials = getInitials(item.actorName)
                Text(
                    text = initials,
                    color = ZholdasTextPrimary,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp
                )
            }

            val badgeConfig = getNotificationIconConfig(item.notificationType)
            Box(
                modifier = Modifier
                    .size(18.dp)
                    .align(Alignment.BottomEnd)
                    .offset(x = 4.dp, y = 4.dp)
                    .clip(CircleShape)
                    .background(badgeConfig.second),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = badgeConfig.first,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(11.dp)
                )
            }
        }

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Text(
                    text = item.text,
                    color = ZholdasTextPrimary,
                    fontSize = 14.sp,
                    lineHeight = 19.sp,
                    modifier = Modifier.weight(1f)
                )

                if (!item.isRead) {
                    Spacer(modifier = Modifier.width(8.dp))
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(ZholdasAccent)
                    )
                }
            }

            Text(
                text = formatNotificationDate(item.createdAt),
                color = ZholdasTextSecondary,
                fontSize = 12.sp
            )
        }
    }
}

private fun getInitials(name: String): String {
    if (name.isBlank()) return "ZH"
    val parts = name.trim().split("\\s+".toRegex())
    return if (parts.size >= 2) {
        "${parts[0].take(1)}${parts[1].take(1)}".uppercase()
    } else {
        parts[0].take(2).uppercase()
    }
}

private fun getNotificationIconConfig(type: String): Pair<androidx.compose.ui.graphics.vector.ImageVector, Color> {
    return when (type) {
        "join" -> Icons.Default.PersonAdd to Color(0xFF2E7D32)
        "leave" -> Icons.Default.PersonRemove to Color(0xFFD32F2F)
        "announcement" -> Icons.Default.Campaign to ZholdasAccent
        "ban" -> Icons.Default.Block to Color(0xFFD32F2F)
        else -> Icons.Default.Notifications to ZholdasAccent
    }
}

private fun formatNotificationDate(rawDate: String): String {
    if (rawDate.isBlank()) return ""
    return try {
        rawDate.take(16).replace("T", " ")
    } catch (e: Exception) {
        rawDate
    }
}
