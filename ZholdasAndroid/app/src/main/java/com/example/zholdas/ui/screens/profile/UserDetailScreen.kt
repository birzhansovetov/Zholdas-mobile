package com.example.zholdas.ui.screens.profile

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
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
import com.example.zholdas.data.model.User
import com.example.zholdas.data.model.UserReview
import com.example.zholdas.theme.*
import com.example.zholdas.ui.AuthViewModel
import com.example.zholdas.ui.components.ModernCard
import com.example.zholdas.ui.components.PrimaryButton
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UserDetailScreen(
    userID: String,
    authViewModel: AuthViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val coroutineScope = rememberCoroutineScope()
    val scrollState = rememberScrollState()

    var user by remember { mutableStateOf<User?>(null) }
    var reviews by remember { mutableStateOf<List<UserReview>>(emptyList()) }
    var friendshipStatus by remember { mutableStateOf("none") }
    var isLoading by remember { mutableStateOf(true) }
    var actionLoading by remember { mutableStateOf(false) }

    var showReportDialog by remember { mutableStateOf(false) }
    var reportReason by remember { mutableStateOf("") }
    var reportSubmitted by remember { mutableStateOf(false) }

    var isBlocked by remember { mutableStateOf(false) }

    val currentUserProfile by authViewModel.currentUserProfile.collectAsState()

    LaunchedEffect(userID) {
        isLoading = true
        user = authViewModel.fetchUserProfile(userID)
        reviews = authViewModel.fetchUserReviews(userID)
        friendshipStatus = authViewModel.getFriendshipStatus(userID)
        isBlocked = friendshipStatus == "blocked"
        isLoading = false
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = ZholdasBackground,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = user?.username?.let { "@$it" } ?: "",
                        color = ZholdasTextPrimary,
                        fontWeight = FontWeight.Bold
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "reg_back".localized,
                            tint = ZholdasTextPrimary
                        )
                    }
                },
                actions = {
                    if (user != null && currentUserProfile?.id != userID) {
                        IconButton(onClick = { showReportDialog = true }) {
                            Icon(
                                imageVector = Icons.Default.ReportProblem,
                                contentDescription = "user_detail_report".localized,
                                tint = ZholdasDanger
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = ZholdasBackground
                )
            )
        }
    ) { innerPadding ->
        if (isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    CircularProgressIndicator(color = ZholdasAccent)
                    Text(
                        text = "prof_loading".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 14.sp
                    )
                }
            }
        } else if (user == null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                    modifier = Modifier.padding(24.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.ErrorOutline,
                        contentDescription = null,
                        tint = ZholdasDanger,
                        modifier = Modifier.size(48.dp)
                    )
                    Text(
                        text = "user_detail_load_error".localized,
                        color = ZholdasTextPrimary,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center
                    )
                    PrimaryButton(
                        text = "btn_retry".localized,
                        onClick = {
                            coroutineScope.launch {
                                isLoading = true
                                user = authViewModel.fetchUserProfile(userID)
                                reviews = authViewModel.fetchUserReviews(userID)
                                friendshipStatus = authViewModel.getFriendshipStatus(userID)
                                isLoading = false
                            }
                        }
                    )
                }
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .verticalScroll(scrollState)
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Avatar & Profile Header
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(100.dp)
                            .clip(CircleShape)
                            .background(
                                brush = Brush.linearGradient(
                                    colors = listOf(
                                        Color(0xFF6B33D4),
                                        Color(0xFF281552)
                                    )
                                )
                            )
                            .border(2.dp, ZholdasAccent.copy(alpha = 0.5f), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = user?.fullName?.take(2)?.uppercase() ?: "ZH",
                            color = Color.White,
                            fontSize = 32.sp,
                            fontWeight = FontWeight.ExtraBold
                        )
                    }

                    Text(
                        text = user?.fullName ?: "",
                        color = ZholdasTextPrimary,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold
                    )

                    Text(
                        text = "@${user?.username ?: ""}",
                        color = ZholdasAccent,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Medium
                    )

                    user?.city?.takeIf { it.isNotBlank() }?.let { city ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.LocationOn,
                                contentDescription = null,
                                tint = ZholdasTextSecondary,
                                modifier = Modifier.size(16.dp)
                            )
                            Text(
                                text = city,
                                color = ZholdasTextSecondary,
                                fontSize = 14.sp
                            )
                        }
                    }
                }

                // Stats Row Card
                ModernCard {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceEvenly,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        StatCell(
                            count = (user?.eventsCount ?: 0).toString(),
                            label = "prof_events_count".localized
                        )
                        Box(
                            modifier = Modifier
                                .width(1.dp)
                                .height(36.dp)
                                .background(Color.White.copy(alpha = 0.1f))
                        )
                        StatCell(
                            count = (user?.friendsCount ?: 0).toString(),
                            label = "prof_friends_count".localized
                        )
                        Box(
                            modifier = Modifier
                                .width(1.dp)
                                .height(36.dp)
                                .background(Color.White.copy(alpha = 0.1f))
                        )
                        StatCell(
                            count = String.format("%.1f ?", user?.rating ?: 5.0),
                            label = "prof_rating_count".localized
                        )
                    }
                }

                // Bio Section
                ModernCard {
                    Text(
                        text = "prof_about_me".localized,
                        color = ZholdasAccent,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = user?.bio?.takeIf { it.isNotBlank() } ?: "user_detail_default_bio".localized,
                        color = ZholdasTextPrimary,
                        fontSize = 14.sp,
                        lineHeight = 20.sp
                    )
                }

                // Action Buttons Section (Friends & Block)
                if (currentUserProfile?.id == userID) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(ZholdasSurface)
                            .padding(12.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "user_detail_its_you".localized,
                            color = ZholdasTextSecondary,
                            fontWeight = FontWeight.Medium
                        )
                    }
                } else if (!isBlocked) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        when (friendshipStatus) {
                            "none" -> {
                                PrimaryButton(
                                    text = "user_detail_add_friend".localized,
                                    onClick = {
                                        coroutineScope.launch {
                                            actionLoading = true
                                            if (authViewModel.sendFriendRequest(userID)) {
                                                friendshipStatus = "pending_sent"
                                            }
                                            actionLoading = false
                                        }
                                    }
                                )
                            }
                            "pending_sent" -> {
                                Button(
                                    onClick = {
                                        coroutineScope.launch {
                                            actionLoading = true
                                            if (authViewModel.rejectFriendRequest(userID)) {
                                                friendshipStatus = "none"
                                            }
                                            actionLoading = false
                                        }
                                    },
                                    modifier = Modifier.fillMaxWidth(),
                                    shape = RoundedCornerShape(12.dp),
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = Color.White.copy(alpha = 0.1f),
                                        contentColor = Color.White
                                    )
                                ) {
                                    Text("user_detail_cancel_request".localized)
                                }
                            }
                            "pending_received" -> {
                                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Text(
                                        text = "user_detail_sent_request".localized,
                                        color = ZholdasAccent,
                                        fontSize = 13.sp
                                    )
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                                    ) {
                                        Button(
                                            onClick = {
                                                coroutineScope.launch {
                                                    actionLoading = true
                                                    if (authViewModel.rejectFriendRequest(userID)) {
                                                        friendshipStatus = "none"
                                                    }
                                                    actionLoading = false
                                                }
                                            },
                                            modifier = Modifier.weight(1f),
                                            shape = RoundedCornerShape(12.dp),
                                            colors = ButtonDefaults.buttonColors(
                                                containerColor = ZholdasDanger.copy(alpha = 0.2f),
                                                contentColor = ZholdasDanger
                                            )
                                        ) {
                                            Text("user_detail_reject".localized)
                                        }

                                        PrimaryButton(
                                            text = "user_detail_accept".localized,
                                            onClick = {
                                                coroutineScope.launch {
                                                    actionLoading = true
                                                    if (authViewModel.acceptFriendRequest(userID)) {
                                                        friendshipStatus = "friends"
                                                    }
                                                    actionLoading = false
                                                }
                                            },
                                            modifier = Modifier.weight(1f)
                                        )
                                    }
                                }
                            }
                            "accepted", "friends" -> {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .weight(1f)
                                            .clip(RoundedCornerShape(12.dp))
                                            .background(ZholdasAccent.copy(alpha = 0.15f))
                                            .border(1.dp, ZholdasAccent.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                                            .padding(vertical = 14.dp),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(
                                            text = "user_detail_friends_status".localized,
                                            color = ZholdasAccent,
                                            fontWeight = FontWeight.Bold
                                        )
                                    }

                                    Button(
                                        onClick = {
                                            coroutineScope.launch {
                                                actionLoading = true
                                                if (authViewModel.rejectFriendRequest(userID)) {
                                                    friendshipStatus = "none"
                                                }
                                                actionLoading = false
                                            }
                                        },
                                        shape = RoundedCornerShape(12.dp),
                                        colors = ButtonDefaults.buttonColors(
                                            containerColor = ZholdasDanger.copy(alpha = 0.15f),
                                            contentColor = ZholdasDanger
                                        )
                                    ) {
                                        Text("user_detail_unfriend".localized)
                                    }
                                }
                            }
                        }

                        // Block User Button
                        Button(
                            onClick = {
                                coroutineScope.launch {
                                    actionLoading = true
                                    if (authViewModel.blockUser(userID)) {
                                        isBlocked = true
                                    }
                                    actionLoading = false
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = ZholdasDanger.copy(alpha = 0.12f),
                                contentColor = ZholdasDanger
                            )
                        ) {
                            Icon(
                                imageVector = Icons.Default.Block,
                                contentDescription = null,
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("user_detail_block".localized)
                        }
                    }
                } else {
                    Button(
                        onClick = {
                            coroutineScope.launch {
                                actionLoading = true
                                if (authViewModel.unblockUser(userID)) {
                                    isBlocked = false
                                    friendshipStatus = "none"
                                }
                                actionLoading = false
                            }
                        },
                        modifier = Modifier
                            .fillMaxWidth(),
                        enabled = !actionLoading,
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = ZholdasAccent.copy(alpha = 0.15f),
                            contentColor = ZholdasAccent
                        )
                    ) {
                        Icon(Icons.Default.LockOpen, contentDescription = null)
                        Spacer(Modifier.width(8.dp))
                        Text(
                            text = when (com.example.zholdas.data.local.Localization.language) {
                                "kk" -> "Бұғаттан шығару"
                                "en" -> "Unblock user"
                                else -> "Разблокировать"
                            },
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }

                // Reviews Section
                ModernCard {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "user_detail_reviews_title".localized,
                            color = ZholdasTextPrimary,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "${reviews.size}",
                            color = ZholdasAccent,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    if (reviews.isEmpty()) {
                        Text(
                            text = "Оценок пока нет",
                            color = ZholdasTextSecondary,
                            fontSize = 13.sp
                        )
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            reviews.forEach { review ->
                                ReviewRow(review = review)
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))
            }
        }
    }

    if (showReportDialog) {
        ReportScreen(
            reportedUserID = userID,
            authViewModel = authViewModel,
            onBack = { showReportDialog = false }
        )
    }
}

@Composable
private fun StatCell(count: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = count,
            color = ZholdasTextPrimary,
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = label,
            color = ZholdasTextSecondary,
            fontSize = 12.sp
        )
    }
}

@Composable
private fun ReviewRow(review: UserReview) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(ZholdasSurface)
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = review.reviewerName.ifBlank { "Участник" },
                color = ZholdasTextPrimary,
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "${review.rating}",
                    color = Color(0xFFFFC107),
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp
                )
                Spacer(modifier = Modifier.width(3.dp))
                Icon(
                    imageVector = Icons.Default.Star,
                    contentDescription = null,
                    tint = Color(0xFFFFC107),
                    modifier = Modifier.size(14.dp)
                )
            }
        }

        if (!review.comment.isNullOrBlank()) {
            Text(
                text = review.comment,
                color = ZholdasTextSecondary,
                fontSize = 13.sp,
                lineHeight = 18.sp
            )
        }
    }
}
