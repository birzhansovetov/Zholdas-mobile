package com.example.zholdas.ui.screens.events

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.zholdas.ZholdasApplication
import com.example.zholdas.data.local.localized
import com.example.zholdas.data.model.Event
import com.example.zholdas.theme.*
import com.example.zholdas.ui.components.ModernCard
import java.util.Locale

@Composable
fun EventListScreen(
    modifier: Modifier = Modifier,
    onNavigateToDetail: ((Event) -> Unit)? = null,
    onNavigateToCreate: (() -> Unit)? = null
) {
    val context = LocalContext.current
    val app = context.applicationContext as ZholdasApplication
    val viewModel: EventsViewModel = viewModel(
        factory = EventsViewModel.Factory(app.container.apiClient)
    )

    var selectedEventForDetail by remember { mutableStateOf<Event?>(null) }
    var selectedEventForEdit by remember { mutableStateOf<Event?>(null) }
    var showCreateScreen by remember { mutableStateOf(false) }
    var showMyEvents by remember { mutableStateOf(false) }

    if (showMyEvents) {
        MyEventsScreen(
            viewModel = viewModel,
            onBack = { showMyEvents = false },
            onEventClick = { selectedEventForDetail = it; showMyEvents = false }
        )
        return
    }

    // If edit screen is open inside host
    val currentEdit = selectedEventForEdit
    if (currentEdit != null) {
        val authVM: com.example.zholdas.ui.AuthViewModel = androidx.lifecycle.viewmodel.compose.viewModel(
            factory = com.example.zholdas.ui.AuthViewModel.Factory(app.container)
        )
        EditEventScreen(
            event = currentEdit,
            authViewModel = authVM,
            onBack = { selectedEventForEdit = null },
            onSuccess = { updated ->
                selectedEventForDetail = updated
                selectedEventForEdit = null
            }
        )
        return
    }

    // If detail screen is open inside host
    val currentSelected = selectedEventForDetail
    if (currentSelected != null && onNavigateToDetail == null) {
        EventDetailScreen(
            event = currentSelected,
            viewModel = viewModel,
            onBack = { selectedEventForDetail = null },
            onEditClick = { eventToEdit ->
                selectedEventForEdit = eventToEdit
            }
        )
        return
    }

    // If create screen is open inside host
    if (showCreateScreen && onNavigateToCreate == null) {
        CreateEventScreen(
            viewModel = viewModel,
            onBack = { showCreateScreen = false },
            onSuccess = { showCreateScreen = false }
        )
        return
    }

    val filteredEvents by viewModel.filteredEvents.collectAsState()
    val selectedCategory by viewModel.selectedCategory.collectAsState()
    val searchQuery by viewModel.searchQuery.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val recommendedEventIDs by viewModel.recommendedEventIDs.collectAsState()

    val categories = remember {
        listOf("cat_all", "cat_mountains", "cat_theater", "cat_restaurant", "cat_sports", "cat_other")
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(ZholdasBackground)
    ) {
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Header Section
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            text = "tab_events".localized,
                            color = ZholdasTextPrimary,
                            fontSize = 28.sp,
                            fontWeight = FontWeight.Bold
                        )
                        val countText = String.format(Locale.getDefault(), "list_events_nearby".localized, filteredEvents.size)
                        Text(
                            text = countText,
                            color = ZholdasTextSecondary,
                            fontSize = 13.sp
                        )
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilledTonalIconButton(onClick = { showMyEvents = true }) {
                        Icon(Icons.Default.EventNote, contentDescription = "Мои события", tint = ZholdasTextPrimary)
                    }
                    Button(
                        onClick = {
                            if (onNavigateToCreate != null) {
                                onNavigateToCreate()
                            } else {
                                showCreateScreen = true
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = ZholdasAccent),
                        shape = RoundedCornerShape(14.dp),
                        contentPadding = PaddingValues(horizontal = 14.dp, vertical = 10.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "Создать",
                            color = Color.White,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    }
                }

                // Search Bar
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(ZholdasPanel)
                        .border(1.dp, ZholdasBorder, RoundedCornerShape(12.dp))
                        .padding(horizontal = 14.dp),
                    contentAlignment = Alignment.CenterStart
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Search,
                            contentDescription = null,
                            tint = ZholdasTextSecondary,
                            modifier = Modifier.size(20.dp)
                        )
                        TextField(
                            value = searchQuery,
                            onValueChange = { viewModel.updateSearchQuery(it) },
                            placeholder = {
                                Text(
                                    text = "Поиск по встречам, локации...",
                                    color = ZholdasTextTertiary,
                                    fontSize = 14.sp
                                )
                            },
                            modifier = Modifier.weight(1f),
                            singleLine = true,
                            colors = TextFieldDefaults.colors(
                                focusedTextColor = ZholdasTextPrimary,
                                unfocusedTextColor = ZholdasTextPrimary,
                                focusedContainerColor = Color.Transparent,
                                unfocusedContainerColor = Color.Transparent,
                                focusedIndicatorColor = Color.Transparent,
                                unfocusedIndicatorColor = Color.Transparent
                            )
                        )
                        if (searchQuery.isNotEmpty()) {
                            IconButton(
                                onClick = { viewModel.updateSearchQuery("") },
                                modifier = Modifier.size(28.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Clear,
                                    contentDescription = null,
                                    tint = ZholdasTextSecondary,
                                    modifier = Modifier.size(18.dp)
                                )
                            }
                        }
                    }
                }
            }

            AnimatedVisibility(visible = errorMessage != null, enter = fadeIn(), exit = fadeOut()) {
                Surface(
                    color = MaterialTheme.colorScheme.errorContainer,
                    contentColor = MaterialTheme.colorScheme.onErrorContainer,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 4.dp),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(errorMessage.orEmpty(), modifier = Modifier.weight(1f), fontSize = 13.sp)
                        IconButton(onClick = viewModel::clearError) {
                            Icon(Icons.Default.Close, contentDescription = "Закрыть сообщение об ошибке")
                        }
                    }
                }
            }

            // Horizontal Category Filter
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 6.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                categories.forEach { cat ->
                    val isSelected = selectedCategory == cat
                    Box(
                        modifier = Modifier
                            .clip(CircleShape)
                            .background(if (isSelected) ZholdasAccentSoft else ZholdasPanel)
                            .border(
                                width = 1.dp,
                                color = if (isSelected) ZholdasAccent.copy(alpha = 0.65f) else ZholdasBorder,
                                shape = CircleShape
                            )
                            .clickable { viewModel.selectCategory(cat) }
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = cat.localized,
                            color = if (isSelected) MaterialTheme.colorScheme.onPrimary else ZholdasTextSecondary,
                            fontSize = 13.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Feed Content
            if (filteredEvents.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 32.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.DirectionsRun,
                            contentDescription = null,
                            tint = Color.Gray,
                            modifier = Modifier.size(64.dp)
                        )
                        Text(
                            text = "list_no_events_found".localized,
                            color = ZholdasTextPrimary,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "list_no_events_hint".localized,
                            color = ZholdasTextSecondary,
                            fontSize = 14.sp,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = 20.dp, vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    items(filteredEvents, key = { it.id }) { event ->
                        EventRowCard(
                            event = event,
                            isRecommended = recommendedEventIDs.contains(event.id),
                            onClick = {
                                if (onNavigateToDetail != null) {
                                    onNavigateToDetail(event)
                                } else {
                                    selectedEventForDetail = event
                                }
                            }
                        )
                    }
                    item {
                        Spacer(modifier = Modifier.height(60.dp))
                    }
                }
            }
        }
    }
}

@Composable
fun EventRowCard(
    event: Event,
    isRecommended: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    ModernCard(
        modifier = modifier.clickable { onClick() }
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            // Top row: category pill + status text
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier
                        .background(
                            color = ZholdasAccent.copy(alpha = if (isRecommended) 0.28f else 0.18f),
                            shape = RoundedCornerShape(6.dp)
                        )
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                ) {
                    Icon(
                        imageVector = EventUtils.getCategoryIcon(event.category),
                        contentDescription = null,
                        tint = ZholdasAccent,
                        modifier = Modifier.size(12.dp)
                    )
                    Text(
                        text = EventUtils.getCategoryNameKey(event.category).localized.uppercase(),
                        color = ZholdasAccent,
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                Text(
                    text = if (event.status == "active") "ev_active".localized else event.status.localized,
                    color = ZholdasSuccess,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium
                )
            }

            // Title
            Text(
                text = event.title,
                color = ZholdasTextPrimary,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold
            )

            // Description
            Text(
                text = event.description,
                color = ZholdasTextSecondary,
                fontSize = 13.sp,
                lineHeight = 18.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )

            HorizontalDivider(color = ZholdasBorder, thickness = 1.dp)

            // Footer row: Date/Time + Location
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.CalendarToday,
                        contentDescription = null,
                        tint = ZholdasAccent,
                        modifier = Modifier.size(14.dp)
                    )
                    Text(
                        text = EventUtils.formatEventDate(event.startTime),
                        color = ZholdasTextSecondary,
                        fontSize = 12.sp
                    )
                }

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier.weight(1f, fill = false)
                ) {
                    Icon(
                        imageVector = Icons.Default.Place,
                        contentDescription = null,
                        tint = ZholdasAccent,
                        modifier = Modifier.size(14.dp)
                    )
                    Text(
                        text = event.locationName,
                        color = ZholdasTextSecondary,
                        fontSize = 12.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }
    }
}
