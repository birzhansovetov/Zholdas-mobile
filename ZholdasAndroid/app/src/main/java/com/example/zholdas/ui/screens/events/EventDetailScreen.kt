package com.example.zholdas.ui.screens.events

import android.Manifest
import android.content.pm.PackageManager
import android.content.Intent
import android.location.Location
import android.net.Uri
import java.util.Locale
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.example.zholdas.data.local.localized
import com.example.zholdas.data.model.Event
import com.example.zholdas.data.model.EventLiveLocation
import com.example.zholdas.data.model.Participant
import com.example.zholdas.theme.*
import com.example.zholdas.ui.components.ModernCard
import com.example.zholdas.ui.components.PrimaryButton
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EventDetailScreen(
    event: Event,
    viewModel: EventsViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    onEditClick: ((Event) -> Unit)? = null
) {
    val context = LocalContext.current
    val scrollState = rememberScrollState()
    val scope = rememberCoroutineScope()
    val locationClient = remember(context) { LocationServices.getFusedLocationProviderClient(context) }

    var isJoined by remember(event) { mutableStateOf(event.isJoined ?: false) }
    var participantsCount by remember(event) { mutableStateOf(event.participantsCount ?: 1) }
    var participantsList by remember { mutableStateOf<List<Participant>>(emptyList()) }
    var showParticipantsSheet by remember { mutableStateOf(false) }
    var participantStatus by remember { mutableStateOf("going") }
    var isSharingLocation by remember { mutableStateOf(false) }
    var liveLocations by remember { mutableStateOf<List<EventLiveLocation>>(emptyList()) }
    var actionError by remember { mutableStateOf<String?>(null) }
    var showPreparation by remember { mutableStateOf(false) }
    var reminderText by remember { mutableStateOf<String?>(null) }
    var pendingLocationAction by remember { mutableStateOf<((Location) -> Unit)?>(null) }

    fun readCurrentLocation(action: (Location) -> Unit) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingLocationAction = action
            return
        }
        locationClient.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, null)
            .addOnSuccessListener { location ->
                if (location != null) action(location) else actionError = "Не удалось получить текущую геопозицию"
            }
            .addOnFailureListener { actionError = it.message ?: "Не удалось получить текущую геопозицию" }
    }

    val locationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        if (permissions.values.any { it }) {
            pendingLocationAction?.let { action -> readCurrentLocation(action) }
        } else {
            actionError = "Для этой функции нужен доступ к геопозиции"
        }
        pendingLocationAction = null
    }

    fun withCurrentLocation(action: (Location) -> Unit) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        ) {
            readCurrentLocation(action)
        } else {
            pendingLocationAction = action
            locationPermissionLauncher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
        }
    }

    LaunchedEffect(event.id) {
        participantsList = viewModel.fetchParticipants(event.id)
        participantStatus = viewModel.fetchCurrentParticipantStatus(event.id, participantsList)
        reminderText = viewModel.eventReminderText(event.id)
    }

    LaunchedEffect(event.id, isSharingLocation) {
        while (isSharingLocation) {
            withCurrentLocation { location ->
                scope.launch {
                    if (!viewModel.updateLiveLocation(event.id, location.latitude, location.longitude, location.accuracy.toDouble())) {
                        isSharingLocation = false
                    }
                    liveLocations = viewModel.fetchLiveLocations(event.id)
                }
            }
            delay(30_000)
        }
    }

    val daysLeftText = remember(event.startTime) {
        EventUtils.calculateDaysLeftText(event.startTime)
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = ZholdasBackground,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = event.title,
                        color = ZholdasTextPrimary,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
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
                    if (onEditClick != null) {
                        IconButton(onClick = { onEditClick(event) }) {
                            Icon(
                                imageVector = Icons.Default.Edit,
                                contentDescription = "prof_edit_btn".localized,
                                tint = ZholdasAccent
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(scrollState)
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Cover Image / Placeholder Banner
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        brush = Brush.linearGradient(
                            colors = listOf(
                                Color(0xFF3B2073),
                                Color(0xFF1D133B)
                            )
                        )
                    )
                    .border(1.dp, ZholdasBorder, RoundedCornerShape(16.dp)),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.AutoAwesome,
                        contentDescription = null,
                        tint = ZholdasAccent,
                        modifier = Modifier.size(36.dp)
                    )
                    Text(
                        text = "ev_default_cover_title".localized,
                        color = ZholdasTextPrimary,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp
                    )
                }
            }

            // Info Card
            ModernCard {
                // Category + Status
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier
                            .background(ZholdasAccent.copy(alpha = 0.18f), RoundedCornerShape(8.dp))
                            .padding(horizontal = 10.dp, vertical = 6.dp)
                    ) {
                        Icon(
                            imageVector = EventUtils.getCategoryIcon(event.category),
                            contentDescription = null,
                            tint = ZholdasAccent,
                            modifier = Modifier.size(14.dp)
                        )
                        Text(
                            text = EventUtils.getCategoryNameKey(event.category).localized.uppercase(),
                            color = ZholdasAccent,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier
                            .background(
                                if (event.status == "active") ZholdasSuccess.copy(alpha = 0.18f) else Color.White.copy(alpha = 0.1f),
                                RoundedCornerShape(8.dp)
                            )
                            .padding(horizontal = 10.dp, vertical = 6.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(6.dp)
                                .clip(CircleShape)
                                .background(if (event.status == "active") ZholdasSuccess else Color.Gray)
                        )
                        Text(
                            text = if (event.status == "active") "ev_status_active".localized else "ev_status_finished".localized,
                            color = if (event.status == "active") ZholdasSuccess else Color.Gray,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }

                Spacer(modifier = Modifier.height(14.dp))

                Text(
                    text = event.title,
                    color = ZholdasTextPrimary,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold
                )

                Spacer(modifier = Modifier.height(4.dp))

                Text(
                    text = daysLeftText,
                    color = ZholdasTextSecondary,
                    fontSize = 13.sp
                )

                Spacer(modifier = Modifier.height(16.dp))

                // Stats grid
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    val remaining = (event.maxParticipants - participantsCount).coerceAtLeast(0)
                    StatMiniCard(
                        title = remaining.toString(),
                        label = "ev_remaining_seats".localized,
                        modifier = Modifier.weight(1f)
                    )
                    StatMiniCard(
                        title = "$participantsCount/${event.maxParticipants}",
                        label = "ev_participants".localized,
                        modifier = Modifier.weight(1f)
                    )
                    StatMiniCard(
                        title = if (event.status == "active") "ev_active".localized else "ev_finished".localized,
                        label = "ev_status".localized,
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            // Organizer Card
            ModernCard {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.08f))
                            .border(1.dp, Color.White.copy(alpha = 0.1f), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Person,
                            contentDescription = null,
                            tint = ZholdasAccent
                        )
                    }
                    Column {
                        Text(
                            text = "ev_organizer".localized.uppercase(),
                            color = ZholdasTextTertiary,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "Абылай Жолдас",
                            color = Color.White,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }

            // Date & Time Card
            ModernCard {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.08f))
                            .border(1.dp, Color.White.copy(alpha = 0.1f), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.CalendarToday,
                            contentDescription = null,
                            tint = ZholdasAccent
                        )
                    }
                    Column {
                        Text(
                            text = "ev_date_time".localized.uppercase(),
                            color = ZholdasTextTertiary,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = EventUtils.formatEventDateFull(event.startTime),
                            color = Color.White,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }

            // Location Card
            ModernCard {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.08f))
                            .border(1.dp, Color.White.copy(alpha = 0.1f), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Place,
                            contentDescription = null,
                            tint = ZholdasDanger
                        )
                    }
                    Column {
                        Text(
                            text = "ev_location".localized.uppercase(),
                            color = ZholdasTextTertiary,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = event.locationName,
                            color = Color.White,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold
                        )
                        val dist = event.distanceMeters
                        if (dist != null) {
                            Text(
                                text = "${"ev_distance".localized}: ${String.format(java.util.Locale.US, "%.1f км", dist / 1000.0)}",
                                color = ZholdasTextSecondary,
                                fontSize = 12.sp
                            )
                        } else {
                            Text(
                                text = "ev_distance_calculating".localized,
                                color = ZholdasTextSecondary,
                                fontSize = 12.sp
                            )
                        }
                    }
                }
            }

            // Restrictions Banner
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color(0xFFE2B93B).copy(alpha = 0.15f))
                    .border(1.dp, Color(0xFFE2B93B).copy(alpha = 0.35f), RoundedCornerShape(12.dp))
                    .padding(14.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Warning,
                        contentDescription = null,
                        tint = Color(0xFFE2B93B)
                    )
                    Text(
                        text = "ev_restrictions".localized,
                        color = Color.White,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }

            // Description Card
            ModernCard {
                Text(
                    text = "create_ev_desc".localized,
                    color = ZholdasTextPrimary,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = event.description,
                    color = ZholdasTextSecondary,
                    fontSize = 14.sp,
                    lineHeight = 20.sp
                )
            }

            // Participants Progress Card
            ModernCard {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "ev_participants".localized,
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "$participantsCount/${event.maxParticipants}",
                        color = ZholdasTextSecondary,
                        fontSize = 14.sp
                    )
                }

                Spacer(modifier = Modifier.height(10.dp))

                val progress = (participantsCount.toFloat() / event.maxParticipants.coerceAtLeast(1).toFloat()).coerceIn(0f, 1f)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(6.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(Color.White.copy(alpha = 0.1f))
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(progress)
                            .height(6.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(ZholdasAccent)
                    )
                }

                Spacer(modifier = Modifier.height(14.dp))

                Button(
                    onClick = { showParticipantsSheet = true },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.White.copy(alpha = 0.08f),
                        contentColor = Color.White
                    )
                ) {
                    Text(
                        text = "ev_view_all_participants".localized,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            // How it runs Card
            ModernCard {
                Text(
                    text = "ev_how_it_runs".localized,
                    color = Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(12.dp))
                RuleRow(icon = Icons.Default.Schedule, text = "ev_how_it_runs_rule1".localized)
                Spacer(modifier = Modifier.height(10.dp))
                RuleRow(icon = Icons.Default.Chat, text = "ev_how_it_runs_rule2".localized)
                Spacer(modifier = Modifier.height(10.dp))
                RuleRow(icon = Icons.Default.Star, text = "ev_how_it_runs_rule3".localized)
            }

            // Join / Leave Button
            if (isJoined) {
                Button(
                    onClick = { showPreparation = true },
                    modifier = Modifier.fillMaxWidth().height(52.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = ZholdasAccent),
                    shape = RoundedCornerShape(14.dp)
                ) {
                    Icon(Icons.Default.Checklist, null)
                    Spacer(Modifier.width(8.dp))
                    Text("Подготовиться к событию", fontWeight = FontWeight.Bold)
                }

                ModernCard {
                    Text("Статус участия", color = ZholdasTextPrimary, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(10.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf("going" to "Иду", "late" to "Опоздаю", "not_going" to "Не приду").forEach { (status, title) ->
                            FilterChip(
                                selected = participantStatus == status,
                                onClick = {
                                    scope.launch {
                                        if (viewModel.updateParticipantStatus(event.id, status)) {
                                            participantStatus = status
                                            participantsList = viewModel.fetchParticipants(event.id)
                                        }
                                    }
                                },
                                label = { Text(title) },
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                    Button(
                        onClick = {
                            withCurrentLocation { location ->
                                scope.launch {
                                    if (viewModel.markArrived(event.id, location.latitude, location.longitude, location.accuracy.toDouble())) {
                                        participantStatus = "arrived"
                                        participantsList = viewModel.fetchParticipants(event.id)
                                    } else actionError = viewModel.errorMessage.value
                                }
                            }
                        },
                        enabled = participantStatus != "arrived",
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(if (participantStatus == "arrived") "Вы на месте" else "Я на месте") }

                    HorizontalDivider(Modifier.padding(vertical = 12.dp), color = Color.White.copy(alpha = .1f))
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("Геопозиция для участников", color = ZholdasTextPrimary, fontWeight = FontWeight.SemiBold)
                            Text("Обновляется каждые 30 секунд", color = ZholdasTextSecondary, fontSize = 12.sp)
                        }
                        Switch(
                            checked = isSharingLocation,
                            onCheckedChange = { enabled ->
                                isSharingLocation = enabled
                                if (!enabled) scope.launch { viewModel.stopLiveLocation(event.id) }
                            }
                        )
                    }
                    TextButton(
                        onClick = { scope.launch { liveLocations = viewModel.fetchLiveLocations(event.id) } },
                        modifier = Modifier.align(Alignment.End)
                    ) { Text("Обновить позиции") }
                    if (liveLocations.isNotEmpty()) {
                        Spacer(Modifier.height(8.dp))
                        liveLocations.forEach { location ->
                            Text("• ${location.fullName.ifBlank { location.username }}", color = ZholdasTextSecondary, fontSize = 13.sp)
                        }
                    }
                    actionError?.let { Text(it, color = ZholdasDanger, fontSize = 12.sp, modifier = Modifier.padding(top = 8.dp)) }
                }

                Button(
                    onClick = {
                        viewModel.leaveEvent(event.id) { success ->
                            if (success) {
                                isJoined = false
                                participantsCount = (participantsCount - 1).coerceAtLeast(0)
                            }
                        }
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    shape = RoundedCornerShape(16.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = ZholdasDanger.copy(alpha = 0.85f),
                        contentColor = Color.White
                    )
                ) {
                    Text(
                        text = "ev_leave_btn".localized,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            } else {
                PrimaryButton(
                    text = "ev_join_btn".localized,
                    onClick = {
                        viewModel.joinEvent(event.id) { success ->
                            if (success) {
                                isJoined = true
                                participantsCount += 1
                            }
                        }
                    }
                )
            }

            // Bottom action buttons: Share & Route
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 24.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Button(
                    onClick = {
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(
                                Intent.EXTRA_TEXT,
                                "${"ev_share_prefix".localized}: ${event.title} ${"ev_share_at".localized} ${event.locationName}!"
                            )
                        }
                        context.startActivity(Intent.createChooser(shareIntent, "ev_share_btn".localized))
                    },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.White.copy(alpha = 0.08f),
                        contentColor = Color.White
                    )
                ) {
                    Text(
                        text = "ev_share_btn".localized,
                        fontWeight = FontWeight.Bold
                    )
                }

                Button(
                    onClick = {
                        val geoUri = Uri.parse("geo:${event.latitude},${event.longitude}?q=${event.latitude},${event.longitude}(${Uri.encode(event.locationName)})")
                        val mapIntent = Intent(Intent.ACTION_VIEW, geoUri)
                        try {
                            context.startActivity(mapIntent)
                        } catch (e: Exception) {
                            // Fallback web google maps
                            val webIntent = Intent(
                                Intent.ACTION_VIEW,
                                Uri.parse("https://maps.google.com/?q=${event.latitude},${event.longitude}")
                            )
                            context.startActivity(webIntent)
                        }
                    },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.White.copy(alpha = 0.08f),
                        contentColor = Color.White
                    )
                ) {
                    Text(
                        text = "ev_route_btn".localized,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }

    if (showParticipantsSheet) {
        ModalBottomSheet(
            onDismissRequest = { showParticipantsSheet = false },
            containerColor = ZholdasElevatedSurface
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = "ev_participants".localized,
                    color = Color.White,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
                if (participantsList.isEmpty()) {
                    Text(
                        text = "ev_participants_empty".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 14.sp
                    )
                } else {
                    LazyColumn(
                        modifier = Modifier.heightIn(max = 350.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(participantsList) { participant ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(Color.White.copy(alpha = 0.04f))
                                    .padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(40.dp)
                                        .clip(CircleShape)
                                        .background(ZholdasAccent.copy(alpha = 0.3f)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Person,
                                        contentDescription = null,
                                        tint = Color.White
                                    )
                                }
                                Column {
                                    Text(
                                        text = participant.fullName.ifBlank { "Участник" },
                                        color = Color.White,
                                        fontWeight = FontWeight.SemiBold
                                    )
                                    Text(
                                        text = "@${participant.username}",
                                        color = ZholdasAccent,
                                        fontSize = 12.sp
                                    )
                                    Text(
                                        text = when (participant.participantStatus) {
                                            "arrived" -> "На месте"
                                            "late" -> "Опоздает"
                                            "not_going" -> "Не придёт"
                                            else -> "Идёт"
                                        },
                                        color = if (participant.participantStatus == "arrived") ZholdasSuccess else ZholdasTextSecondary,
                                        fontSize = 11.sp
                                    )
                                }
                            }
                        }
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }

    if (showPreparation) {
        ModalBottomSheet(
            onDismissRequest = { showPreparation = false },
            containerColor = ZholdasElevatedSurface
        ) {
            Column(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                Text("Подготовка", color = ZholdasTextPrimary, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                Text(preparationCountdown(event.startTime), color = ZholdasAccent, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                PreparationRow(Icons.Default.Schedule, "Начало", eventLocalTime(event.startTime))
                PreparationRow(Icons.Default.Place, "Место", event.locationName)
                PreparationRow(
                    Icons.Default.HowToReg,
                    "Ваш статус",
                    when (participantStatus) { "arrived" -> "На месте"; "late" -> "Опоздаю"; "not_going" -> "Не приду"; else -> "Иду" }
                )
                reminderText?.let {
                    Surface(color = ZholdasAccent.copy(alpha = .15f), shape = RoundedCornerShape(12.dp)) {
                        Row(Modifier.fillMaxWidth().padding(12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Icon(Icons.Default.NotificationsActive, null, tint = ZholdasAccent)
                            Column {
                                Text("Напоминание", color = ZholdasTextPrimary, fontWeight = FontWeight.Bold)
                                Text(it, color = ZholdasTextSecondary, fontSize = 13.sp)
                            }
                        }
                    }
                } ?: Text("Напоминание появится в приложении перед началом события", color = ZholdasTextSecondary, fontSize = 13.sp)
                Text("Возьмите заряженный телефон, проверьте маршрут и сообщите организатору, если опаздываете.", color = ZholdasTextSecondary, fontSize = 13.sp)
                Button(
                    onClick = {
                        val uri = Uri.parse("geo:${event.latitude},${event.longitude}?q=${event.latitude},${event.longitude}(${Uri.encode(event.locationName)})")
                        context.startActivity(Intent(Intent.ACTION_VIEW, uri))
                    },
                    modifier = Modifier.fillMaxWidth()
                ) { Icon(Icons.Default.Route, null); Spacer(Modifier.width(8.dp)); Text("Построить маршрут") }
                Spacer(Modifier.height(20.dp))
            }
        }
    }
}

@Composable
private fun PreparationRow(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, value: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Icon(icon, null, tint = ZholdasAccent)
        Column {
            Text(title, color = ZholdasTextSecondary, fontSize = 12.sp)
            Text(value, color = ZholdasTextPrimary, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun RuleRow(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String) {
    Row(
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = ZholdasAccent,
            modifier = Modifier.size(18.dp)
        )
        Text(
            text = text,
            color = ZholdasTextSecondary,
            fontSize = 13.sp,
            lineHeight = 18.sp
        )
    }
}

@Composable
private fun StatMiniCard(
    title: String,
    label: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White.copy(alpha = 0.04f))
            .border(1.dp, Color.White.copy(alpha = 0.06f), RoundedCornerShape(12.dp))
            .padding(vertical = 10.dp, horizontal = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = title,
            color = Color.White,
            fontWeight = FontWeight.Bold,
            fontSize = 16.sp
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = label,
            color = ZholdasTextSecondary,
            fontSize = 11.sp
        )
    }
}
