package com.example.zholdas.ui.screens.profile

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PersonRemove
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.example.zholdas.data.local.localized
import com.example.zholdas.data.model.User
import com.example.zholdas.theme.*
import com.example.zholdas.ui.AuthViewModel
import kotlinx.coroutines.launch

@Composable
fun FriendsListScreen(
    authViewModel: AuthViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val scope = rememberCoroutineScope()
    var friends by remember { mutableStateOf<List<User>>(emptyList()) }
    var requests by remember { mutableStateOf<List<User>>(emptyList()) }
    var selectedTab by remember { mutableStateOf(0) } // 0: Friends, 1: Requests
    var isLoadingData by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        isLoadingData = true
        val f = authViewModel.fetchFriends()
        val r = authViewModel.fetchFriendRequests()
        friends = f
        requests = r
        isLoadingData = false
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(ZholdasBackground)
    ) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Top Navigation Bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onBack) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = null,
                        tint = ZholdasTextPrimary
                    )
                }

                Spacer(modifier = Modifier.width(8.dp))

                Text(
                    text = "friends_title".localized,
                    color = ZholdasTextPrimary,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            // Tab Picker
            PickerView(
                selectedTab = selectedTab,
                onTabSelected = { selectedTab = it },
                friendsCount = friends.size,
                requestsCount = requests.size,
                modifier = Modifier
                    .padding(horizontal = 20.dp)
                    .padding(top = 10.dp)
            )

            Spacer(modifier = Modifier.height(16.dp))

            if (isLoadingData) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        CircularProgressIndicator(
                            color = ZholdasAccent,
                            modifier = Modifier.size(36.dp)
                        )
                        Text(
                            text = "prof_loading".localized,
                            color = ZholdasTextSecondary,
                            fontSize = 14.sp
                        )
                    }
                }
            } else {
                if (selectedTab == 0) {
                    FriendsListContent(
                        friends = friends,
                        onRemoveFriend = { friend ->
                            scope.launch {
                                val success = authViewModel.rejectFriendRequest(friend.id)
                                if (success) {
                                    friends = friends.filterNot { it.id == friend.id }
                                }
                            }
                        }
                    )
                } else {
                    RequestsListContent(
                        requests = requests,
                        onAccept = { request ->
                            scope.launch {
                                val success = authViewModel.acceptFriendRequest(request.id)
                                if (success) {
                                    val accepted = requests.find { it.id == request.id }
                                    requests = requests.filterNot { it.id == request.id }
                                    if (accepted != null) {
                                        friends = friends + accepted
                                    }
                                }
                            }
                        },
                        onReject = { request ->
                            scope.launch {
                                val success = authViewModel.rejectFriendRequest(request.id)
                                if (success) {
                                    requests = requests.filterNot { it.id == request.id }
                                }
                            }
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun PickerView(
    selectedTab: Int,
    onTabSelected: (Int) -> Unit,
    friendsCount: Int,
    requestsCount: Int,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.Black.copy(alpha = 0.25f))
            .border(1.dp, ZholdasBorder, RoundedCornerShape(12.dp))
            .padding(4.dp)
    ) {
        listOf(0, 1).forEach { index ->
            val isSelected = selectedTab == index
            val bgColor by animateColorAsState(
                targetValue = if (isSelected) ZholdasElevatedSurface else Color.Transparent,
                label = "tabBgColor"
            )

            Row(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(10.dp))
                    .background(bgColor)
                    .clickable { onTabSelected(index) }
                    .padding(vertical = 12.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = if (index == 0) "friends_my_friends".localized else "friends_requests".localized,
                    color = if (isSelected) ZholdasTextPrimary else ZholdasTextSecondary,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp
                )

                Spacer(modifier = Modifier.width(8.dp))

                val count = if (index == 0) friendsCount else requestsCount
                val badgeColor = when {
                    index == 1 && count > 0 -> Color.Red
                    isSelected -> ZholdasAccent
                    else -> ZholdasBorder
                }

                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(badgeColor)
                        .padding(horizontal = 8.dp, vertical = 2.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = count.toString(),
                        color = Color.White,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

@Composable
private fun FriendsListContent(
    friends: List<User>,
    onRemoveFriend: (User) -> Unit
) {
    if (friends.isEmpty()) {
        EmptyStateView(
            icon = Icons.Default.Person,
            title = "friends_empty_title".localized,
            subtitle = "friends_empty_subtitle".localized
        )
    } else {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            contentPadding = PaddingValues(top = 8.dp, bottom = 24.dp)
        ) {
            items(friends, key = { it.id }) { friend ->
                FriendRow(friend = friend, onRemove = { onRemoveFriend(friend) })
            }
        }
    }
}

@Composable
private fun RequestsListContent(
    requests: List<User>,
    onAccept: (User) -> Unit,
    onReject: (User) -> Unit
) {
    if (requests.isEmpty()) {
        EmptyStateView(
            icon = Icons.Default.Notifications,
            title = "friends_empty_requests_title".localized,
            subtitle = "friends_empty_requests_subtitle".localized
        )
    } else {
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            contentPadding = PaddingValues(top = 8.dp, bottom = 24.dp)
        ) {
            items(requests, key = { it.id }) { request ->
                RequestRow(
                    request = request,
                    onAccept = { onAccept(request) },
                    onReject = { onReject(request) }
                )
            }
        }
    }
}

@Composable
private fun FriendRow(
    friend: User,
    onRemove: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(ZholdasSurface)
            .border(1.dp, ZholdasBorder, RoundedCornerShape(16.dp))
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AvatarView(user = friend, size = 50)

        Spacer(modifier = Modifier.width(16.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = friend.fullName,
                color = ZholdasTextPrimary,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = "@${friend.username}",
                color = ZholdasTextSecondary,
                fontSize = 13.sp
            )
        }

        IconButton(
            onClick = onRemove,
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(Color.Red.copy(alpha = 0.1f))
        ) {
            Icon(
                imageVector = Icons.Default.PersonRemove,
                contentDescription = null,
                tint = Color.Red.copy(alpha = 0.8f),
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

@Composable
private fun RequestRow(
    request: User,
    onAccept: () -> Unit,
    onReject: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(ZholdasSurface)
            .border(1.dp, ZholdasBorder, RoundedCornerShape(16.dp))
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AvatarView(user = request, size = 50)

        Spacer(modifier = Modifier.width(16.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = request.fullName,
                color = ZholdasTextPrimary,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = "@${request.username}",
                color = ZholdasTextSecondary,
                fontSize = 13.sp
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            IconButton(
                onClick = onReject,
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.1f))
            ) {
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(18.dp)
                )
            }

            IconButton(
                onClick = onAccept,
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(
                        brush = Brush.linearGradient(
                            colors = listOf(ZholdasAccent, ZholdasAccentDeep)
                        )
                    )
            ) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}

@Composable
private fun AvatarView(
    user: User,
    size: Int
) {
    Box(
        modifier = Modifier
            .size(size.dp)
            .clip(CircleShape)
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(Color(0xFF402673), Color(0xFF261440))
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        if (!user.avatarURL.isNullOrEmpty()) {
            AsyncImage(
                model = user.avatarURL,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(size.dp)
                    .clip(CircleShape)
            )
        } else {
            Text(
                text = getInitials(user.fullName),
                color = ZholdasTextPrimary,
                fontSize = (size * 0.36).toInt().sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
private fun EmptyStateView(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    subtitle: String
) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier
                .padding(horizontal = 40.dp)
                .padding(bottom = 60.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = ZholdasAccent.copy(alpha = 0.7f),
                modifier = Modifier.size(60.dp)
            )

            Text(
                text = title,
                color = Color.White,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold
            )

            Text(
                text = subtitle,
                color = ZholdasTextSecondary,
                fontSize = 14.sp,
                textAlign = TextAlign.Center
            )
        }
    }
}

private fun getInitials(name: String): String {
    val parts = name.trim().split(" ").filter { it.isNotEmpty() }
    return when {
        parts.size >= 2 -> "${parts[0].take(1)}${parts[1].take(1)}".uppercase()
        parts.isNotEmpty() -> parts[0].take(2).uppercase()
        else -> "??"
    }
}
