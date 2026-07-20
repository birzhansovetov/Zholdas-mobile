package com.example.zholdas.ui.main

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.zholdas.data.AppContainer
import com.example.zholdas.data.local.localized
import com.example.zholdas.theme.ZholdasAccent
import com.example.zholdas.theme.ZholdasBackground
import com.example.zholdas.theme.ZholdasDanger
import com.example.zholdas.ui.AuthViewModel
import com.example.zholdas.ui.screens.activity.ActivityScreen
import com.example.zholdas.ui.screens.chats.ChatListScreen
import com.example.zholdas.ui.screens.events.EventListScreen
import com.example.zholdas.ui.screens.map.MapScreen
import com.example.zholdas.ui.screens.profile.ProfileScreen

sealed class TabItem(val titleKey: String, val icon: androidx.compose.ui.graphics.vector.ImageVector) {
    object Map : TabItem("tab_map", Icons.Default.Map)
    object Events : TabItem("tab_events", Icons.AutoMirrored.Filled.List)
    object Chats : TabItem("tab_chats", Icons.AutoMirrored.Filled.Chat)
    object Activity : TabItem("tab_activity", Icons.Default.Notifications)
    object Profile : TabItem("tab_profile", Icons.Default.Person)
}

@Composable
fun MainAppShell(
    authViewModel: AuthViewModel,
    modifier: Modifier = Modifier
) {
    var selectedTab by remember { mutableStateOf<TabItem>(TabItem.Map) }
    val unreadNotificationsCount by authViewModel.unreadNotificationsCount.collectAsState()

    val tabs = listOf(
        TabItem.Map,
        TabItem.Events,
        TabItem.Chats,
        TabItem.Activity,
        TabItem.Profile
    )

    Scaffold(
        modifier = modifier,
        bottomBar = {
            NavigationBar(
                containerColor = ZholdasBackground,
                modifier = Modifier
                    .border(
                        width = 1.dp,
                        color = MaterialTheme.colorScheme.outlineVariant
                    )
            ) {
                tabs.forEach { tab ->
                    val isSelected = selectedTab == tab
                    val badgeCount = if (tab == TabItem.Activity) unreadNotificationsCount else 0

                    NavigationBarItem(
                        selected = isSelected,
                        onClick = { selectedTab = tab },
                        icon = {
                            BadgedBox(
                                badge = {
                                    if (badgeCount > 0) {
                                        Badge(
                                            containerColor = ZholdasDanger,
                                            contentColor = Color.White
                                        ) {
                                            Text(badgeCount.toString(), fontSize = 10.sp)
                                        }
                                    }
                                }
                            ) {
                                Icon(
                                    imageVector = tab.icon,
                                    contentDescription = tab.titleKey.localized,
                                    modifier = Modifier.size(24.dp)
                                )
                            }
                        },
                        label = {
                            Text(
                                text = tab.titleKey.localized,
                                fontSize = 10.sp,
                                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Medium
                            )
                        },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = MaterialTheme.colorScheme.onPrimary,
                            selectedTextColor = MaterialTheme.colorScheme.onPrimary,
                            indicatorColor = ZholdasAccent,
                            unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                            unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    )
                }
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            when (selectedTab) {
                TabItem.Map -> MapScreen()
                TabItem.Events -> EventListScreen()
                TabItem.Chats -> ChatListScreen()
                TabItem.Activity -> ActivityScreen(authViewModel)
                TabItem.Profile -> ProfileScreen(authViewModel)
            }
        }
    }
}
