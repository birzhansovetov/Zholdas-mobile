package com.example.zholdas.ui.screens.map

import android.content.Context
import android.content.pm.PackageManager
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.zholdas.data.model.Event
import com.example.zholdas.theme.*
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.MarkerComposable
import com.google.maps.android.compose.rememberCameraPositionState
import com.google.maps.android.compose.rememberMarkerState

@Composable
fun MapScreen(
    modifier: Modifier = Modifier,
    viewModel: MapViewModel = viewModel(factory = MapViewModel.Factory),
    onEventDetailClick: (Event) -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current

    val isGoogleKeyConfigured = remember(context) {
        isGoogleMapsApiKeyConfigured(context)
    }

    // Determine whether to show fallback map
    val useFallbackMap = uiState.isFallbackMode || !isGoogleKeyConfigured

    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(
            LatLng(MapViewModel.DEFAULT_LATITUDE, MapViewModel.DEFAULT_LONGITUDE),
            12f
        )
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(ZholdasBackground)
    ) {
        // 1. Map Layer (Google Maps Compose OR Safe Interactive Fallback Map)
        if (useFallbackMap) {
            FallbackAlmatyMapView(
                events = uiState.filteredEvents,
                selectedEvent = uiState.selectedEvent,
                onSelectEvent = { event -> viewModel.selectEvent(event) },
                modifier = Modifier.fillMaxSize()
            )
        } else {
            GoogleMap(
                modifier = Modifier.fillMaxSize(),
                cameraPositionState = cameraPositionState,
                properties = MapProperties(isMyLocationEnabled = false),
                uiSettings = MapUiSettings(
                    zoomControlsEnabled = false,
                    compassEnabled = false,
                    myLocationButtonEnabled = false
                )
            ) {
                // User location center annotation
                MarkerComposable(
                    state = rememberMarkerState(
                        position = LatLng(MapViewModel.DEFAULT_LATITUDE, MapViewModel.DEFAULT_LONGITUDE)
                    ),
                    title = "Вы здесь"
                ) {
                    UserLocationMarker()
                }

                // Event markers
                uiState.filteredEvents.forEach { event ->
                    MarkerComposable(
                        state = rememberMarkerState(
                            position = LatLng(event.latitude, event.longitude)
                        ),
                        title = event.title,
                        onClick = {
                            viewModel.selectEvent(event)
                            true
                        }
                    ) {
                        EventMarkerIcon(
                            category = event.category,
                            isSelected = uiState.selectedEvent?.id == event.id
                        )
                    }
                }
            }
        }

        // 2. Top Filter Overlay (City Info, Search, Categories)
        MapTopFiltersSection(
            eventsCount = uiState.filteredEvents.count(),
            selectedCategory = uiState.selectedCategory,
            searchQuery = uiState.searchQuery,
            errorMessage = uiState.errorMessage,
            isFallbackMode = useFallbackMap,
            onCategorySelected = { category -> viewModel.selectCategory(category) },
            onSearchQueryChanged = { query -> viewModel.updateSearchQuery(query) },
            onAIRecommendations = viewModel::requestAIRecommendations,
            onToggleMapMode = { viewModel.toggleFallbackMode() },
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

        // 3. Control Buttons (Recenter, Mode Switch)
        Column(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 16.dp, bottom = if (uiState.selectedEvent != null) 230.dp else 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Recenter Button
            FloatingActionButton(
                onClick = {
                    cameraPositionState.position = CameraPosition.fromLatLngZoom(
                        LatLng(MapViewModel.DEFAULT_LATITUDE, MapViewModel.DEFAULT_LONGITUDE),
                        12f
                    )
                },
                containerColor = ZholdasElevatedSurface,
                contentColor = ZholdasAccent,
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Place,
                    contentDescription = "Центр Алматы"
                )
            }

            // Toggle Map Engine Button
            FloatingActionButton(
                onClick = { viewModel.toggleFallbackMode() },
                containerColor = if (useFallbackMap) ZholdasAccent else ZholdasElevatedSurface,
                contentColor = Color.White,
                modifier = Modifier.size(48.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "Переключить режим карты"
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
    isFallbackMode: Boolean,
    onCategorySelected: (String) -> Unit,
    onSearchQueryChanged: (String) -> Unit,
    onAIRecommendations: () -> Unit,
    onToggleMapMode: () -> Unit,
    modifier: Modifier = Modifier
) {
    val focusManager = LocalFocusManager.current

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        // Offline / Fallback banner if applicable
        if (errorMessage != null || isFallbackMode) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(ZholdasAccent.copy(alpha = 0.88f))
                    .clickable { onToggleMapMode() }
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
                    text = errorMessage ?: "Интерактивная карта Алматы (Фоллбэк режим без Google API)",
                    color = Color.White,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f)
                )
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
                        Text(
                            text = "Алматы · Центр (43.2389, 76.8897)",
                            color = ZholdasTextSecondary,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "Карта событий Жолдас",
                        color = ZholdasTextPrimary,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                Badge(
                    containerColor = ZholdasAccent.copy(alpha = 0.2f),
                    contentColor = ZholdasAccent
                ) {
                    Text(
                        text = "$eventsCount ивентов",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }
        }

        // Search Bar
        OutlinedTextField(
            value = searchQuery,
            onValueChange = onSearchQueryChanged,
            placeholder = {
                Text(
                    text = "Поиск по названию или месту...",
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
                            contentDescription = "Очистить",
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
                        color = Color.White,
                        fontSize = 13.sp,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp)
                    )
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
                Text("Рекомендации Жорика", color = ZholdasTextPrimary, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                IconButton(onClick = onDismiss) { Icon(Icons.Default.Close, "Закрыть", tint = ZholdasTextSecondary) }
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
                Text("Подходящих событий на карте пока нет", color = ZholdasTextSecondary)
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
                        contentDescription = "Закрыть",
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
                        text = "?? ${event.locationName}",
                        color = ZholdasTextSecondary,
                        fontSize = 12.sp
                    )
                    Text(
                        text = "?? ${event.startTime}",
                        color = ZholdasTextSecondary,
                        fontSize = 12.sp
                    )
                }

                Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = "?? ${event.participantsCount ?: 0} / ${event.maxParticipants}",
                        color = ZholdasTextSecondary,
                        fontSize = 12.sp
                    )
                    event.distanceMeters?.let { distance ->
                        Text(
                            text = if (distance >= 1000) String.format("%.1f км", distance / 1000) else "${distance.toInt()} м",
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
                    text = "Подробнее об ивенте",
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

@Composable
fun FallbackAlmatyMapView(
    events: List<Event>,
    selectedEvent: Event?,
    onSelectEvent: (Event) -> Unit,
    modifier: Modifier = Modifier
) {
    var panOffset by remember { mutableStateOf(Offset.Zero) }

    Box(
        modifier = modifier
            .background(
                Brush.verticalGradient(
                    colors = listOf(ZholdasBackgroundDeep, ZholdasBackground)
                )
            )
            .pointerInput(Unit) {
                detectDragGestures { change, dragAmount ->
                    change.consume()
                    panOffset += dragAmount
                }
            }
    ) {
        // Decorative grid & Almaty schematic map background
        Canvas(modifier = Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height

            // Grid lines
            val gridSize = 80f
            var x = panOffset.x % gridSize
            while (x < w) {
                drawLine(
                    color = Color.White.copy(alpha = 0.04f),
                    start = Offset(x, 0f),
                    end = Offset(x, h),
                    strokeWidth = 1f
                )
                x += gridSize
            }
            var y = panOffset.y % gridSize
            while (y < h) {
                drawLine(
                    color = Color.White.copy(alpha = 0.04f),
                    start = Offset(0f, y),
                    end = Offset(w, y),
                    strokeWidth = 1f
                )
                y += gridSize
            }

            // Schematic Almaty main roads
            val centerX = w / 2 + panOffset.x
            val centerY = h / 2 + panOffset.y

            // Al-Farabi Avenue (horizontal south)
            drawLine(
                color = Color.White.copy(alpha = 0.12f),
                start = Offset(0f, centerY + 120f),
                end = Offset(w, centerY + 120f),
                strokeWidth = 4f
            )

            // Abay Avenue (horizontal middle)
            drawLine(
                color = Color.White.copy(alpha = 0.09f),
                start = Offset(0f, centerY - 20f),
                end = Offset(w, centerY - 20f),
                strokeWidth = 3f
            )

            // Dostyk Avenue (vertical east)
            drawLine(
                color = Color.White.copy(alpha = 0.09f),
                start = Offset(centerX + 90f, 0f),
                end = Offset(centerX + 90f, h),
                strokeWidth = 3f
            )

            // Mountains contour in South
            val mountainsPath = Path().apply {
                moveTo(0f, h - 30f)
                lineTo(w * 0.2f, h - 90f)
                lineTo(w * 0.4f, h - 60f)
                lineTo(w * 0.65f, h - 130f)
                lineTo(w * 0.85f, h - 80f)
                lineTo(w, h - 110f)
            }
            drawPath(
                path = mountainsPath,
                color = ZholdasSuccess.copy(alpha = 0.2f),
                style = Stroke(width = 3f)
            )

            // Center city ring (Almaty center 43.2389, 76.8897)
            drawCircle(
                color = ZholdasAccent.copy(alpha = 0.06f),
                radius = 160f,
                center = Offset(centerX, centerY)
            )
        }

        // Center User location marker
        Box(
            modifier = Modifier
                .align(Alignment.Center)
                .offset(x = panOffset.x.dp / 2, y = panOffset.y.dp / 2)
        ) {
            UserLocationMarker()
        }

        // Event Pins on fallback map
        events.forEach { event ->
            // Compute relative offset around Almaty center (43.2389, 76.8897)
            val dLat = (event.latitude - MapViewModel.DEFAULT_LATITUDE) * 4500.0
            val dLon = (event.longitude - MapViewModel.DEFAULT_LONGITUDE) * 3200.0

            val offsetX = (dLon + panOffset.x).dp
            val offsetY = (-dLat + panOffset.y).dp

            Box(
                modifier = Modifier
                    .align(Alignment.Center)
                    .offset(x = offsetX, y = offsetY)
                    .clickable { onSelectEvent(event) }
            ) {
                EventMarkerIcon(
                    category = event.category,
                    isSelected = selectedEvent?.id == event.id
                )
            }
        }
    }
}

fun isGoogleMapsApiKeyConfigured(context: Context): Boolean {
    return try {
        val appInfo = context.packageManager.getApplicationInfo(
            context.packageName,
            PackageManager.GET_META_DATA
        )
        val apiKey = appInfo.metaData?.getString("com.google.android.geo.API_KEY")
        !apiKey.isNullOrBlank() && apiKey != "YOUR_GOOGLE_MAPS_API_KEY_HERE"
    } catch (e: Exception) {
        false
    }
}

fun getCategoryTitle(cat: String): String {
    return when (cat.lowercase()) {
        "cat_all" -> "Все"
        "cat_mountains", "hiking", "mountain" -> "Горы"
        "cat_theater", "theater" -> "Театр"
        "cat_restaurant", "restaurant", "food" -> "Еда"
        "cat_sports", "sport" -> "Спорт"
        "cat_other", "board_games" -> "Другое"
        else -> "Ивенты"
    }
}

fun getCategoryColor(category: String): Color {
    val ec = category.lowercase()
    return when {
        ec.contains("hiking") || ec.contains("mountain") || ec.contains("гор") -> ZholdasSuccess
        ec.contains("sport") || ec.contains("run") || ec.contains("football") || ec.contains("спорт") -> ZholdasAccent
        ec.contains("theater") || ec.contains("театр") -> Color(0xFFB042FF)
        ec.contains("restaurant") || ec.contains("food") || ec.contains("cafe") || ec.contains("ресторан") -> ZholdasDanger
        ec.contains("board_games") || ec.contains("game") -> Color(0xFF3B82F6)
        else -> Color(0xFF7C66DC)
    }
}

fun getCategoryEmoji(category: String): String {
    val ec = category.lowercase()
    return when {
        ec.contains("hiking") || ec.contains("mountain") || ec.contains("гор") -> "🏔️"
        ec.contains("sport") || ec.contains("run") || ec.contains("football") || ec.contains("спорт") -> "🏃"
        ec.contains("theater") || ec.contains("театр") -> "🎭"
        ec.contains("restaurant") || ec.contains("food") || ec.contains("cafe") || ec.contains("ресторан") -> "🍴"
        ec.contains("board_games") || ec.contains("game") -> "??"
        else -> "?"
    }
}
