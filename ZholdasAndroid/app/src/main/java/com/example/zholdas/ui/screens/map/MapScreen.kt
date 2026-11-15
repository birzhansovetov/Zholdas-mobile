package com.example.zholdas.ui.screens.map

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.zholdas.data.local.localized
import com.example.zholdas.data.model.Event
import com.example.zholdas.theme.*
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import org.maplibre.android.geometry.LatLng

@Composable
fun MapScreen(
    modifier: Modifier = Modifier,
    viewModel: MapViewModel = viewModel(factory = MapViewModel.Factory),
    onEventDetailClick: (Event) -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val mapController = remember(context) { OpenMapController(context) }
    val locationClient = remember(context) { LocationServices.getFusedLocationProviderClient(context) }

    var hasRequestedInitialPermission by rememberSaveable { mutableStateOf(false) }
    var isRequestingFromFab by remember { mutableStateOf(false) }
    var currentCameraTarget by remember { mutableStateOf<LatLng?>(null) }
    var userLocation by remember { mutableStateOf<LatLng?>(null) }

    fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    fun fetchLocationAndCenter(onFailureOrDenied: (() -> Unit)? = null) {
        if (!hasLocationPermission()) {
            onFailureOrDenied?.invoke()
            return
        }
        try {
            locationClient.getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, null)
                .addOnSuccessListener { location ->
                    if (location != null) {
                        val latLng = LatLng(location.latitude, location.longitude)
                        userLocation = latLng
                        mapController.updateUserLocation(latLng)
                        mapController.moveTo(latLng, zoom = 13.0, animate = true)
                        viewModel.loadNearbyEvents(location.latitude, location.longitude)
                    } else {
                        onFailureOrDenied?.invoke()
                    }
                }
                .addOnFailureListener {
                    onFailureOrDenied?.invoke()
                }
        } catch (_: SecurityException) {
            onFailureOrDenied?.invoke()
        }
    }

    val locationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val granted = permissions.values.any { it }
        val fromFab = isRequestingFromFab
        isRequestingFromFab = false
        if (granted) {
            fetchLocationAndCenter(onFailureOrDenied = {
                if (fromFab) {
                    mapController.recenter()
                }
            })
        } else {
            if (fromFab) {
                mapController.recenter()
            }
        }
    }

    LaunchedEffect(Unit) {
        if (!hasRequestedInitialPermission) {
            hasRequestedInitialPermission = true
            if (hasLocationPermission()) {
                fetchLocationAndCenter()
            } else {
                locationPermissionLauncher.launch(
                    arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
                )
            }
        }
    }

    val showSearchHere = remember(currentCameraTarget, uiState.lastLoadedLat, uiState.lastLoadedLon) {
        val target = currentCameraTarget ?: return@remember false
        val results = FloatArray(1)
        android.location.Location.distanceBetween(
            uiState.lastLoadedLat,
            uiState.lastLoadedLon,
            target.latitude,
            target.longitude,
            results
        )
        results[0] > 1500f
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(ZholdasBackground)
    ) {
        OpenStreetMapView(
            controller = mapController,
            events = uiState.filteredEvents,
            selectedEvent = uiState.selectedEvent,
            recommendedIds = uiState.aiRecommendedEvents.map { it.id }.toSet(),
            onSelectEvent = viewModel::selectEvent,
            onCameraIdle = { center ->
                currentCameraTarget = center
            },
            modifier = Modifier.fillMaxSize()
        )
        // 2. Top Filter Overlay (City Info, Search, Categories)
        MapTopFiltersSection(
            eventsCount = uiState.filteredEvents.count(),
            selectedCategory = uiState.selectedCategory,
            searchQuery = uiState.searchQuery,
            errorMessage = uiState.errorMessage,
            isLoading = uiState.isLoading,
            showSearchHere = showSearchHere,
            hasUserLocation = userLocation != null,
            onRetry = viewModel::retryLoadNearbyEvents,
            onSearchHereClick = {
                currentCameraTarget?.let { target ->
                    viewModel.loadNearbyEvents(target.latitude, target.longitude)
                }
            },
            onCategorySelected = { category -> viewModel.selectCategory(category) },
            onSearchQueryChanged = { query -> viewModel.updateSearchQuery(query) },
            onAIRecommendations = viewModel::requestAIRecommendations,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .statusBarsPadding()
        )

        AnimatedVisibility(
            visible = uiState.isAiLoading || uiState.aiAnswer != null || uiState.aiError != null,
            modifier = Modifier.align(Alignment.CenterStart).padding(horizontal = 16.dp)
        ) {
            AIRecommendationsCard(
                isLoading = uiState.isAiLoading,
                answer = uiState.aiAnswer,
                events = uiState.aiRecommendedEvents,
                error = uiState.aiError,
                onEventClick = { viewModel.selectEvent(it) },
                onDismiss = viewModel::dismissAIRecommendations
            )
        }

        // Recenter control
        Column(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 16.dp, bottom = if (uiState.selectedEvent != null) 230.dp else 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // My Location Button
            FloatingActionButton(
                onClick = {
                    if (hasLocationPermission()) {
                        fetchLocationAndCenter(onFailureOrDenied = {
                            mapController.recenter()
                        })
                    } else {
                        isRequestingFromFab = true
                        locationPermissionLauncher.launch(
                            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
                        )
                    }
                },
                containerColor = ZholdasElevatedSurface,
                contentColor = ZholdasAccent,
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.MyLocation,
                    contentDescription = "map_my_location".localized
                )
            }

        }

        // 4. Selected Event Bottom Card
        AnimatedVisibility(
            visible = uiState.selectedEvent != null,
            enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
            exit = slideOutVertically(targetOffsetY = { it }) + fadeOut(),
            modifier = Modifier.align(Alignment.BottomCenter)
        ) {
            uiState.selectedEvent?.let { event ->
                SelectedEventBottomCard(
                    event = event,
                    onClose = { viewModel.selectEvent(null) },
                    onDetailClick = { onEventDetailClick(event) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                )
            }
        }
    }
}

@Composable
fun MapTopFiltersSection(
    eventsCount: Int,
    selectedCategory: String,
    searchQuery: String,
    errorMessage: String?,
    isLoading: Boolean = false,
    showSearchHere: Boolean = false,
    hasUserLocation: Boolean = false,
    onRetry: () -> Unit = {},
    onSearchHereClick: () -> Unit = {},
    onCategorySelected: (String) -> Unit,
    onSearchQueryChanged: (String) -> Unit,
    onAIRecommendations: () -> Unit,
    modifier: Modifier = Modifier
) {
    val focusManager = LocalFocusManager.current

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        // Backend error banner
        if (errorMessage != null) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(ZholdasAccent.copy(alpha = 0.88f))
                    .padding(horizontal = 14.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Info,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(16.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = errorMessage.orEmpty(),
                    color = Color.White,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f)
                )
                TextButton(
                    onClick = onRetry,
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 0.dp)
                ) {
                    Text(
                        text = "common_retry".localized,
                        color = Color.White,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }

        // City Card
        Surface(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            color = ZholdasElevatedSurface.copy(alpha = 0.92f),
            shadowElevation = 8.dp
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .border(
                        width = 1.dp,
                        color = Color.White.copy(alpha = 0.1f),
                        shape = RoundedCornerShape(16.dp)
                    )
                    .padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(ZholdasSuccess)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        val headerCityText = if (hasUserLocation) "map_header_near_you".localized else "map_header_default_city".localized
                        Text(
                            text = headerCityText,
                            color = ZholdasTextSecondary,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "map_events_title".localized,
                        color = ZholdasTextPrimary,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                Badge(
                    containerColor = ZholdasAccent.copy(alpha = 0.2f),
                    contentColor = ZholdasAccent
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    ) {
                        if (isLoading) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(12.dp),
                                strokeWidth = 2.dp,
                                color = ZholdasAccent
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                        }
                        Text(
                            text = String.format("map_events_count".localized, eventsCount),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
        }

        // Search Bar
        OutlinedTextField(
            value = searchQuery,
            onValueChange = onSearchQueryChanged,
            placeholder = {
                Text(
                    text = "map_search_by_name_or_place".localized,
                    color = ZholdasTextSecondary,
                    fontSize = 14.sp
                )
            },
            leadingIcon = {
                Icon(
                    imageVector = Icons.Default.Search,
                    contentDescription = null,
                    tint = ZholdasAccent
                )
            },
            trailingIcon = {
                if (searchQuery.isNotEmpty()) {
                    IconButton(onClick = onAIRecommendations) {
                        Icon(
                            imageVector = Icons.Default.AutoAwesome,
                            contentDescription = "common_clear".localized,
                            tint = ZholdasTextSecondary
                        )
                    }
                }
            },
            singleLine = true,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = { focusManager.clearFocus(); onAIRecommendations() }),
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(ZholdasElevatedSurface.copy(alpha = 0.92f)),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = ZholdasTextPrimary,
                unfocusedTextColor = ZholdasTextPrimary,
                focusedBorderColor = ZholdasAccent,
                unfocusedBorderColor = ZholdasBorder,
                cursorColor = ZholdasAccent
            )
        )

        // Categories Horizontal Filter
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            items(MapViewModel.categories) { categoryKey ->
                val isSelected = selectedCategory == categoryKey
                val title = getCategoryTitle(categoryKey)
                val catColor = getCategoryColor(categoryKey)

                Surface(
                    shape = RoundedCornerShape(20.dp),
                    color = if (isSelected) catColor else ZholdasElevatedSurface.copy(alpha = 0.9f),
                    modifier = Modifier
                        .clickable { onCategorySelected(categoryKey) }
                        .border(
                            width = 1.dp,
                            color = if (isSelected) Color.White.copy(alpha = 0.4f) else Color.White.copy(alpha = 0.12f),
                            shape = RoundedCornerShape(20.dp)
                        )
                ) {
                    Text(
                        text = title,
                        color = if (isSelected) Color.White else ZholdasTextPrimary,
                        fontSize = 13.sp,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp)
                    )
                }
            }
        }

        // Search here button
        if (showSearchHere) {
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                Surface(
                    onClick = onSearchHereClick,
                    shape = RoundedCornerShape(20.dp),
                    color = ZholdasElevatedSurface,
                    shadowElevation = 6.dp,
                    border = androidx.compose.foundation.BorderStroke(1.dp, ZholdasAccent.copy(alpha = 0.4f))
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = null,
                            tint = ZholdasAccent,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "map_search_here".localized,
                            color = ZholdasTextPrimary,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AIRecommendationsCard(
    isLoading: Boolean,
    answer: String?,
    events: List<Event>,
    error: String?,
    onEventClick: (Event) -> Unit,
    onDismiss: () -> Unit
) {
    Surface(shape = RoundedCornerShape(20.dp), color = ZholdasElevatedSurface, tonalElevation = 8.dp) {
        Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.AutoAwesome, null, tint = ZholdasAccent)
                Spacer(Modifier.width(8.dp))
                Text("map_ai_recs_header".localized, color = ZholdasTextPrimary, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                IconButton(onClick = onDismiss) { Icon(Icons.Default.Close, "common_close".localized, tint = ZholdasTextSecondary) }
            }
            if (isLoading) LinearProgressIndicator(Modifier.fillMaxWidth())
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            answer?.takeIf { it.isNotBlank() }?.let { Text(it, color = ZholdasTextSecondary, maxLines = 4, overflow = TextOverflow.Ellipsis) }
            events.forEach { event ->
                Surface(Modifier.fillMaxWidth().clickable { onEventClick(event) }, shape = RoundedCornerShape(12.dp), color = ZholdasSurface) {
                    Column(Modifier.padding(12.dp)) {
                        Text(event.title, color = ZholdasTextPrimary, fontWeight = FontWeight.SemiBold)
                        Text(event.locationName, color = ZholdasTextSecondary, fontSize = 12.sp)
                    }
                }
            }
            if (!isLoading && error == null && answer != null && events.isEmpty()) {
                Text("map_no_matching_events".localized, color = ZholdasTextSecondary)
            }
        }
    }
}

@Composable
fun SelectedEventBottomCard(
    event: Event,
    onClose: () -> Unit,
    onDetailClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val catColor = getCategoryColor(event.category)
    val catTitle = getCategoryTitle(event.category)

    Surface(
        modifier = modifier
            .shadow(elevation = 16.dp, shape = RoundedCornerShape(20.dp)),
        shape = RoundedCornerShape(20.dp),
        color = ZholdasElevatedSurface
    ) {
        Column(
            modifier = Modifier
                .border(
                    width = 1.dp,
                    color = Color.White.copy(alpha = 0.12f),
                    shape = RoundedCornerShape(20.dp)
                )
                .padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Category tag and Close button
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = catColor.copy(alpha = 0.2f)
                ) {
                    Text(
                        text = catTitle,
                        color = catColor,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                    )
                }

                IconButton(
                    onClick = onClose,
                    modifier = Modifier.size(28.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "common_close".localized,
                        tint = ZholdasTextSecondary
                    )
                }
            }

            // Title
            Text(
                text = event.title,
                color = ZholdasTextPrimary,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )

            // Description
            if (event.description.isNotBlank()) {
                Text(
                    text = event.description,
                    color = ZholdasTextSecondary,
                    fontSize = 13.sp,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }

            // Details info row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = "📍 ${event.locationName}",
                        color = ZholdasTextSecondary,
                        fontSize = 12.sp
                    )
                    Text(
                        text = "📅 ${event.startTime}",
                        color = ZholdasTextSecondary,
                        fontSize = 12.sp
                    )
                }

                Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = "👥 ${event.participantsCount ?: 0} / ${event.maxParticipants}",
                        color = ZholdasTextSecondary,
                        fontSize = 12.sp
                    )
                    event.distanceMeters?.let { distance ->
                        Text(
                            text = if (distance >= 1000) String.format(java.util.Locale.US, "%.1f %s", distance / 1000.0, "unit_km".localized) else "${distance.toInt()} ${"unit_m".localized}",
                            color = ZholdasAccent,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(2.dp))

            // Action button
            Button(
                onClick = onDetailClick,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = ZholdasAccent,
                    contentColor = Color.White
                )
            ) {
                Text(
                    text = "map_event_detail_btn".localized,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(vertical = 4.dp)
                )
            }
        }
    }
}

@Composable
fun UserLocationMarker() {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier.size(48.dp)
    ) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(ZholdasAccent.copy(alpha = 0.25f))
        )
        Box(
            modifier = Modifier
                .size(20.dp)
                .clip(CircleShape)
                .background(ZholdasAccent)
                .border(2.dp, Color.White, CircleShape)
        )
    }
}

@Composable
fun EventMarkerIcon(
    category: String,
    isSelected: Boolean
) {
    val color = getCategoryColor(category)

    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier.size(if (isSelected) 46.dp else 38.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .clip(CircleShape)
                .background(color)
                .border(if (isSelected) 3.dp else 2.dp, Color.White, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = getCategoryEmoji(category),
                fontSize = if (isSelected) 18.sp else 15.sp
            )
        }
    }
}

fun getCategoryTitle(cat: String): String {
    return EventCategories.getFilterKey(cat).localized
}

fun getCategoryColor(category: String): Color {
    val key = EventCategories.getFilterKey(category)
    return when (key) {
        "cat_mountains" -> ZholdasSuccess
        "cat_sports" -> ZholdasAccent
        "cat_theater" -> Color(0xFFB042FF)
        "cat_restaurant" -> ZholdasDanger
        else -> Color(0xFF3B82F6)
    }
}

fun getCategoryEmoji(category: String): String {
    val key = EventCategories.getFilterKey(category)
    return when (key) {
        "cat_mountains" -> "🏔️"
        "cat_sports" -> "🏃"
        "cat_theater" -> "🎭"
        "cat_restaurant" -> "🍴"
        else -> "🎲"
    }
}
