package com.example.zholdas.ui.screens.profile

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
import com.example.zholdas.data.model.Event
import com.example.zholdas.data.model.Participant
import com.example.zholdas.theme.*
import com.example.zholdas.ui.AuthViewModel
import com.example.zholdas.ui.components.ModernCard
import com.example.zholdas.ui.components.PrimaryButton
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RateParticipantsScreen(
    event: Event,
    authViewModel: AuthViewModel,
    onFinish: () -> Unit,
    modifier: Modifier = Modifier
) {
    val coroutineScope = rememberCoroutineScope()
    val currentUserProfile by authViewModel.currentUserProfile.collectAsState()

    var participants by remember { mutableStateOf<List<Participant>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var ratedParticipantIDs by remember { mutableStateOf<Set<String>>(emptySet()) }

    var selectedParticipant by remember { mutableStateOf<Participant?>(null) }
    var selectedRating by remember { mutableStateOf(5) }
    var commentText by remember { mutableStateOf("") }
    var isSubmitting by remember { mutableStateOf(false) }

    LaunchedEffect(event.id) {
        isLoading = true
        try {
            val list = authViewModel.apiClient.apiService.getEventParticipants(event.id)
            val currentId = currentUserProfile?.id
            participants = list.filter { it.id != currentId }
        } catch (e: Exception) {
            participants = emptyList()
        }
        isLoading = false
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = ZholdasBackground,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "ev_rate_participants".localized,
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                },
                actions = {
                    TextButton(onClick = onFinish) {
                        Text(
                            text = "btn_done".localized,
                            color = ZholdasAccent,
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = ZholdasBackground
                )
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Subtitle Banner
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(ZholdasAccent.copy(alpha = 0.15f))
                    .border(1.dp, ZholdasAccent.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
                    .padding(14.dp)
            ) {
                Text(
                    text = "rate_subtitle".localized,
                    color = Color.White,
                    fontSize = 14.sp,
                    lineHeight = 20.sp
                )
            }

            if (isLoading) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = ZholdasAccent)
                }
            } else if (participants.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier.padding(24.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.PeopleOutline,
                            contentDescription = null,
                            tint = ZholdasTextSecondary,
                            modifier = Modifier.size(56.dp)
                        )
                        Text(
                            text = "rate_no_participants_title".localized,
                            color = Color.White,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold,
                            textAlign = TextAlign.Center
                        )
                        Text(
                            text = "rate_no_participants_desc".localized,
                            color = ZholdasTextSecondary,
                            fontSize = 14.sp,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(participants) { participant ->
                        val isRated = ratedParticipantIDs.contains(participant.id)
                        ParticipantRateRow(
                            participant = participant,
                            isRated = isRated,
                            onRateClick = {
                                selectedParticipant = participant
                                selectedRating = 5
                                commentText = ""
                            }
                        )
                    }
                }
            }
        }
    }

    // Modal Bottom Sheet for Rating
    selectedParticipant?.let { participant ->
        ModalBottomSheet(
            onDismissRequest = { selectedParticipant = null },
            containerColor = ZholdasElevatedSurface
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 12.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(
                    text = "rate_sheet_title".localized,
                    color = Color.White,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold
                )

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .clip(CircleShape)
                            .background(
                                brush = Brush.linearGradient(
                                    colors = listOf(
                                        Color(0xFF6B33D4),
                                        Color(0xFF281552)
                                    )
                                )
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = participant.fullName.take(2).uppercase().ifBlank { "ZH" },
                            color = Color.White,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }

                    Column {
                        Text(
                            text = participant.fullName.ifBlank { "Участник" },
                            color = Color.White,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "@${participant.username}",
                            color = ZholdasAccent,
                            fontSize = 13.sp
                        )
                    }
                }

                Spacer(modifier = Modifier.height(4.dp))

                // Interactive Star Row (1 to 5)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    for (star in 1..5) {
                        Icon(
                            imageVector = if (star <= selectedRating) Icons.Default.Star else Icons.Default.StarBorder,
                            contentDescription = null,
                            tint = if (star <= selectedRating) Color(0xFFFFC107) else Color.White.copy(alpha = 0.3f),
                            modifier = Modifier
                                .size(44.dp)
                                .clickable { selectedRating = star }
                                .padding(4.dp)
                        )
                    }
                }

                // Star Rating Description
                Text(
                    text = getRatingDescription(selectedRating),
                    color = Color.White,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = TextAlign.Center
                )

                // Review Comment
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        text = "rate_comment_label".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                    OutlinedTextField(
                        value = commentText,
                        onValueChange = { commentText = it },
                        placeholder = {
                            Text(
                                "rate_comment_placeholder".localized,
                                color = ZholdasTextSecondary
                            )
                        },
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedTextColor = Color.White,
                            unfocusedTextColor = Color.White,
                            focusedBorderColor = ZholdasAccent,
                            unfocusedBorderColor = Color.White.copy(alpha = 0.2f)
                        ),
                        modifier = Modifier.fillMaxWidth(),
                        minLines = 3
                    )
                }

                Spacer(modifier = Modifier.height(8.dp))

                PrimaryButton(
                    text = if (isSubmitting) "prof_loading".localized else "rate_submit_btn".localized,
                    onClick = {
                        coroutineScope.launch {
                            isSubmitting = true
                            val success = authViewModel.rateParticipant(
                                eventID = event.id,
                                rateeID = participant.id,
                                rating = selectedRating,
                                comment = commentText.takeIf { it.isNotBlank() }
                            )
                            if (success) {
                                ratedParticipantIDs = ratedParticipantIDs + participant.id
                                selectedParticipant = null
                            }
                            isSubmitting = false
                        }
                    }
                )

                Spacer(modifier = Modifier.height(24.dp))
            }
        }
    }
}

@Composable
private fun ParticipantRateRow(
    participant: Participant,
    isRated: Boolean,
    onRateClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Color.White.copy(alpha = 0.05f))
            .border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(14.dp))
            .padding(14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(46.dp)
                    .clip(CircleShape)
                    .background(ZholdasAccent.copy(alpha = 0.25f)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = participant.fullName.take(2).uppercase().ifBlank { "ZH" },
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            }

            Column {
                Text(
                    text = participant.fullName.ifBlank { "Участник" },
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp
                )
                Text(
                    text = "@${participant.username}",
                    color = ZholdasAccent,
                    fontSize = 13.sp
                )
            }
        }

        if (isRated) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(Color(0xFF2E7D32).copy(alpha = 0.2f))
                    .padding(horizontal = 10.dp, vertical = 6.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = null,
                    tint = Color(0xFF4CAF50),
                    modifier = Modifier.size(16.dp)
                )
                Text(
                    text = "rate_rated_badge".localized,
                    color = Color(0xFF4CAF50),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        } else {
            Button(
                onClick = onRateClick,
                shape = RoundedCornerShape(10.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = ZholdasAccent,
                    contentColor = Color.White
                ),
                contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Star,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = "rate_rate_btn".localized,
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp
                )
            }
        }
    }
}

private fun getRatingDescription(rating: Int): String {
    return when (rating) {
        1 -> "rate_star_1".localized
        2 -> "rate_star_2".localized
        3 -> "rate_star_3".localized
        4 -> "rate_star_4".localized
        else -> "rate_star_5".localized
    }
}
