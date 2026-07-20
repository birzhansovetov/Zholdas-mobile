package com.example.zholdas.ui.screens.events

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.zholdas.data.local.localized
import com.example.zholdas.theme.*
import com.example.zholdas.ui.components.ModernCard
import com.example.zholdas.ui.components.PrimaryButton
import com.example.zholdas.ui.components.modernFieldSurface
import coil.compose.AsyncImage
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateEventScreen(
    viewModel: EventsViewModel,
    onBack: () -> Unit,
    onSuccess: () -> Unit,
    modifier: Modifier = Modifier
) {
    val scrollState = rememberScrollState()
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()

    var title by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("hiking") }
    var locationName by remember { mutableStateOf("") }
    var latitude by remember { mutableStateOf(43.2389) }
    var longitude by remember { mutableStateOf(76.8897) }
    var maxParticipants by remember { mutableStateOf(10) }
    var visibility by remember { mutableStateOf("public") }
    var genderFilter by remember { mutableStateOf("all") }
    var minAge by remember { mutableStateOf("") }
    var maxAge by remember { mutableStateOf("") }
    var selectedImageUri by remember { mutableStateOf<Uri?>(null) }
    var isUploadingImage by remember { mutableStateOf(false) }
    var imageUploadError by remember { mutableStateOf<String?>(null) }
    var showLocationPickerDialog by remember { mutableStateOf(false) }

    val categoriesList = remember {
        listOf("hiking", "walk", "sports", "board_games", "networking", "theater", "restaurant")
    }

    val isLoading by viewModel.isLoading.collectAsState()
    val hasSelectedCover = selectedImageUri != null
    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) {
            selectedImageUri = uri
            imageUploadError = null
        }
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = ZholdasBackground,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "create_ev_nav_title".localized,
                        color = ZholdasTextPrimary,
                        fontWeight = FontWeight.Bold
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "create_ev_cancel".localized,
                            tint = ZholdasTextPrimary
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
                .verticalScroll(scrollState)
                .padding(horizontal = 20.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // 1. Cover Photo Picker
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "create_ev_cover".localized.uppercase(),
                    color = ZholdasTextTertiary,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold
                )
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(140.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (hasSelectedCover) ZholdasAccent.copy(alpha = 0.25f) else Color.White.copy(alpha = 0.05f))
                        .border(1.dp, if (hasSelectedCover) ZholdasAccent else ZholdasBorder, RoundedCornerShape(14.dp))
                        .clickable(enabled = !isUploadingImage) {
                            photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                        },
                    contentAlignment = Alignment.Center
                ) {
                    selectedImageUri?.let { uri ->
                        AsyncImage(
                            model = uri,
                            contentDescription = "Selected event cover",
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                    Column(
                        modifier = if (hasSelectedCover) Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(Color.Black.copy(alpha = 0.55f))
                            .padding(12.dp) else Modifier,
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            imageVector = if (hasSelectedCover) Icons.Default.CheckCircle else Icons.Default.AddPhotoAlternate,
                            contentDescription = null,
                            tint = ZholdasAccent,
                            modifier = Modifier.size(36.dp)
                        )
                        Text(
                            text = if (hasSelectedCover) "Обложка выбрана (нажмите для смены)" else "create_ev_select_photo".localized,
                            color = if (hasSelectedCover) Color.White else ZholdasTextSecondary,
                            fontSize = 14.sp
                        )
                    }
                }
                if (imageUploadError != null) {
                    Text(imageUploadError!!, color = ZholdasDanger, fontSize = 13.sp)
                }
            }

            // 2. Title Input
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "create_ev_title_label".localized.uppercase(),
                    color = ZholdasTextTertiary,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold
                )
                TextField(
                    value = title,
                    onValueChange = { title = it },
                    placeholder = {
                        Text(
                            text = "create_ev_title_placeholder".localized,
                            color = ZholdasTextTertiary
                        )
                    },
                    modifier = Modifier.modernFieldSurface(isFocused = title.isNotEmpty()),
                    colors = TextFieldDefaults.colors(
                        focusedTextColor = ZholdasTextPrimary,
                        unfocusedTextColor = ZholdasTextPrimary,
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent
                    ),
                    singleLine = true
                )
            }

            // 3. Category Picker
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "create_ev_category".localized.uppercase(),
                    color = ZholdasTextTertiary,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    categoriesList.take(3).forEach { cat ->
                        CategorySelectChip(
                            category = cat,
                            isSelected = category == cat,
                            onClick = { category = cat },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    categoriesList.drop(3).take(3).forEach { cat ->
                        CategorySelectChip(
                            category = cat,
                            isSelected = category == cat,
                            onClick = { category = cat },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }

            // 4. Description
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "create_ev_desc".localized.uppercase(),
                    color = ZholdasTextTertiary,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold
                )
                TextField(
                    value = description,
                    onValueChange = { description = it },
                    placeholder = {
                        Text(
                            text = "Опишите маршрут, программу или требования для участников...",
                            color = ZholdasTextTertiary
                        )
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(110.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(ZholdasPanel)
                        .border(1.dp, ZholdasBorder, RoundedCornerShape(12.dp)),
                    colors = TextFieldDefaults.colors(
                        focusedTextColor = ZholdasTextPrimary,
                        unfocusedTextColor = ZholdasTextPrimary,
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent
                    )
                )
            }

            // 5. Location and Map Point
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "create_ev_location_label".localized.uppercase(),
                    color = ZholdasTextTertiary,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold
                )
                TextField(
                    value = locationName,
                    onValueChange = { locationName = it },
                    placeholder = {
                        Text(
                            text = "create_ev_location_placeholder".localized,
                            color = ZholdasTextTertiary
                        )
                    },
                    modifier = Modifier.modernFieldSurface(isFocused = locationName.isNotEmpty()),
                    colors = TextFieldDefaults.colors(
                        focusedTextColor = ZholdasTextPrimary,
                        unfocusedTextColor = ZholdasTextPrimary,
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent
                    ),
                    singleLine = true
                )

                // Pick point on map button
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(ZholdasSurface)
                        .border(1.dp, ZholdasBorder, RoundedCornerShape(12.dp))
                        .clickable { showLocationPickerDialog = true }
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Place,
                            contentDescription = null,
                            tint = ZholdasAccent
                        )
                        Column {
                            Text(
                                text = "create_ev_pick_location".localized,
                                color = Color.White,
                                fontWeight = FontWeight.SemiBold
                            )
                            Text(
                                text = String.format(Locale.US, "%.4f, %.4f", latitude, longitude),
                                color = ZholdasTextSecondary,
                                fontSize = 12.sp
                            )
                        }
                    }
                    Icon(
                        imageVector = Icons.Default.ChevronRight,
                        contentDescription = null,
                        tint = ZholdasTextSecondary
                    )
                }
            }

            // 6. Max Participants Stepper
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "create_ev_participants_label".localized.uppercase(),
                    color = ZholdasTextTertiary,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(ZholdasSurface)
                        .border(1.dp, ZholdasBorder, RoundedCornerShape(12.dp))
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = "$maxParticipants ${"create_ev_people_count".localized}",
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        IconButton(
                            onClick = { if (maxParticipants > 2) maxParticipants -= 1 },
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(Color.White.copy(alpha = 0.1f))
                        ) {
                            Text("-", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                        }
                        IconButton(
                            onClick = { if (maxParticipants < 100) maxParticipants += 1 },
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(ZholdasAccent.copy(alpha = 0.3f))
                        ) {
                            Text("+", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            // 7. Visibility
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "create_ev_visibility_header".localized.uppercase(),
                    color = ZholdasTextTertiary,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    val publicText = "create_ev_visibility_all".localized
                    val friendsText = "create_ev_visibility_friends".localized

                    VisibilityOptionChip(
                        title = publicText,
                        icon = Icons.Default.Public,
                        isSelected = visibility == "public",
                        onClick = { visibility = "public" },
                        modifier = Modifier.weight(1f)
                    )
                    VisibilityOptionChip(
                        title = friendsText,
                        icon = Icons.Default.People,
                        isSelected = visibility == "friends",
                        onClick = { visibility = "friends" },
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            // 8. Audience / Gender & Age
            ModernCard {
                Text(
                    text = "create_ev_audience_header".localized,
                    color = Color.White,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(10.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    GenderOptionChip(
                        title = "create_ev_gender_all".localized,
                        isSelected = genderFilter == "all",
                        onClick = { genderFilter = "all" },
                        modifier = Modifier.weight(1f)
                    )
                    GenderOptionChip(
                        title = "create_ev_gender_men".localized,
                        isSelected = genderFilter == "men",
                        onClick = { genderFilter = "men" },
                        modifier = Modifier.weight(1f)
                    )
                    GenderOptionChip(
                        title = "create_ev_gender_women".localized,
                        isSelected = genderFilter == "women",
                        onClick = { genderFilter = "women" },
                        modifier = Modifier.weight(1f)
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = "create_ev_age_range_label".localized,
                    color = ZholdasTextSecondary,
                    fontSize = 12.sp
                )
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    TextField(
                        value = minAge,
                        onValueChange = { minAge = it.filter { ch -> ch.isDigit() }.take(2) },
                        placeholder = { Text("18", color = ZholdasTextTertiary) },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        modifier = Modifier
                            .width(70.dp)
                            .height(48.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(Color.White.copy(alpha = 0.05f)),
                        colors = TextFieldDefaults.colors(
                            focusedTextColor = Color.White,
                            unfocusedTextColor = Color.White,
                            focusedContainerColor = Color.Transparent,
                            unfocusedContainerColor = Color.Transparent,
                            focusedIndicatorColor = Color.Transparent,
                            unfocusedIndicatorColor = Color.Transparent
                        )
                    )
                    Text("—", color = ZholdasTextSecondary)
                    TextField(
                        value = maxAge,
                        onValueChange = { maxAge = it.filter { ch -> ch.isDigit() }.take(2) },
                        placeholder = { Text("45", color = ZholdasTextTertiary) },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        modifier = Modifier
                            .width(70.dp)
                            .height(48.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(Color.White.copy(alpha = 0.05f)),
                        colors = TextFieldDefaults.colors(
                            focusedTextColor = Color.White,
                            unfocusedTextColor = Color.White,
                            focusedContainerColor = Color.Transparent,
                            unfocusedContainerColor = Color.Transparent,
                            focusedIndicatorColor = Color.Transparent,
                            unfocusedIndicatorColor = Color.Transparent
                        )
                    )
                    Text("create_ev_years".localized, color = ZholdasTextSecondary, fontSize = 13.sp)
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Submit Button
            val isFormValid = title.isNotBlank() && locationName.isNotBlank()
            PrimaryButton(
                text = "create_ev_btn".localized,
                onClick = {
                    val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
                    val now = System.currentTimeMillis()
                    val startTimeStr = isoFormat.format(Date(now + 3600000L))
                    val endTimeStr = isoFormat.format(Date(now + 7200000L))

                    coroutineScope.launch {
                        isUploadingImage = selectedImageUri != null
                        imageUploadError = null
                        val uploadedUrl = try {
                            selectedImageUri?.let { viewModel.uploadEventImage(context.contentResolver, it) }
                        } catch (error: Exception) {
                            imageUploadError = error.message ?: "Не удалось загрузить фотографию. Повторите попытку."
                            null
                        } finally {
                            isUploadingImage = false
                        }
                        if (selectedImageUri != null && uploadedUrl == null) return@launch
                        viewModel.createEvent(
                            title = title,
                            description = description,
                            category = category,
                            locationName = locationName,
                            latitude = latitude,
                            longitude = longitude,
                            startTime = startTimeStr,
                            endTime = endTimeStr,
                            maxParticipants = maxParticipants,
                            imageURL = uploadedUrl,
                            visibility = visibility,
                            genderFilter = genderFilter,
                            minAge = minAge.toIntOrNull(),
                            maxAge = maxAge.toIntOrNull(),
                            onResult = { success -> if (success) onSuccess() }
                        )
                    }
                },
                isLoading = isLoading || isUploadingImage,
                enabled = isFormValid && !isUploadingImage
            )

            Spacer(modifier = Modifier.height(24.dp))
        }
    }

    if (showLocationPickerDialog) {
        AlertDialog(
            onDismissRequest = { showLocationPickerDialog = false },
            containerColor = ZholdasElevatedSurface,
            title = {
                Text(
                    text = "create_ev_pick_location".localized,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        text = "create_ev_map_tap_hint".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 14.sp
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceEvenly
                    ) {
                        Button(
                            onClick = {
                                latitude = 43.1872
                                longitude = 76.9531
                                if (locationName.isBlank()) locationName = "Кок-Жайляу"
                                showLocationPickerDialog = false
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = ZholdasAccent.copy(alpha = 0.25f))
                        ) {
                            Text("Горы (43.18, 76.95)", color = Color.White)
                        }
                        Button(
                            onClick = {
                                latitude = 43.2567
                                longitude = 76.9754
                                if (locationName.isBlank()) locationName = "Парк Горького"
                                showLocationPickerDialog = false
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = ZholdasAccent.copy(alpha = 0.25f))
                        ) {
                            Text("Центр (43.25, 76.97)", color = Color.White)
                        }
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        showLocationPickerDialog = false
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = ZholdasAccent)
                ) {
                    Text("create_ev_confirm_location".localized, color = Color.White)
                }
            }
        )
    }
}

@Composable
private fun CategorySelectChip(
    category: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .background(if (isSelected) ZholdasAccent else Color.White.copy(alpha = 0.05f))
            .border(1.dp, if (isSelected) ZholdasAccent else Color.White.copy(alpha = 0.1f), RoundedCornerShape(10.dp))
            .clickable { onClick() }
            .padding(vertical = 10.dp, horizontal = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Icon(
                imageVector = EventUtils.getCategoryIcon(category),
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(18.dp)
            )
            Text(
                text = EventUtils.getCategoryNameKey(category).localized,
                color = Color.White,
                fontSize = 11.sp,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
            )
        }
    }
}

@Composable
private fun VisibilityOptionChip(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(if (isSelected) ZholdasAccent.copy(alpha = 0.2f) else Color.White.copy(alpha = 0.04f))
            .border(1.dp, if (isSelected) ZholdasAccent else Color.White.copy(alpha = 0.08f), RoundedCornerShape(12.dp))
            .clickable { onClick() }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = if (isSelected) ZholdasAccent else Color.Gray,
            modifier = Modifier.size(18.dp)
        )
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            text = title,
            color = if (isSelected) Color.White else Color.Gray,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
private fun GenderOptionChip(
    title: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(if (isSelected) ZholdasAccent.copy(alpha = 0.2f) else Color.White.copy(alpha = 0.04f))
            .border(1.dp, if (isSelected) ZholdasAccent else Color.White.copy(alpha = 0.08f), RoundedCornerShape(12.dp))
            .clickable { onClick() }
            .padding(vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = title,
            color = if (isSelected) Color.White else Color.Gray,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold
        )
    }
}
