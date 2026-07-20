package com.example.zholdas.ui.screens.events

import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.example.zholdas.data.local.localized
import com.example.zholdas.data.model.CreateEventRequest
import com.example.zholdas.data.model.Event
import com.example.zholdas.theme.*
import com.example.zholdas.ui.AuthViewModel
import com.example.zholdas.ui.components.ModernCard
import com.example.zholdas.ui.components.PrimaryButton
import coil.compose.AsyncImage
import kotlinx.coroutines.launch

@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
fun EditEventScreen(
    event: Event,
    authViewModel: AuthViewModel,
    onBack: () -> Unit,
    onSuccess: (Event) -> Unit,
    modifier: Modifier = Modifier
) {
    val coroutineScope = rememberCoroutineScope()
    val context = LocalContext.current

    var title by remember { mutableStateOf(event.title) }
    var description by remember { mutableStateOf(event.description) }
    var category by remember { mutableStateOf(event.category.ifBlank { "cat_mountains" }) }
    var locationName by remember { mutableStateOf(event.locationName) }
    var latitude by remember { mutableStateOf(event.latitude.toString()) }
    var longitude by remember { mutableStateOf(event.longitude.toString()) }
    var maxParticipants by remember { mutableStateOf(event.maxParticipants.takeIf { it > 0 } ?: 10) }
    var genderFilter by remember { mutableStateOf(event.genderFilter ?: "All") }
    var minAgeText by remember { mutableStateOf(event.minAge?.toString() ?: "") }
    var maxAgeText by remember { mutableStateOf(event.maxAge?.toString() ?: "") }
    var selectedImageUri by remember { mutableStateOf<Uri?>(null) }
    var imageUploadError by remember { mutableStateOf<String?>(null) }

    var isSubmitting by remember { mutableStateOf(false) }
    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) {
            selectedImageUri = uri
            imageUploadError = null
        }
    }

    val categories = remember {
        listOf(
            "cat_mountains",
            "cat_walks",
            "cat_sports",
            "cat_theater",
            "cat_restaurant",
            "cat_games",
            "cat_networking",
            "cat_other"
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "edit_ev_nav_title".localized,
                        style = MaterialTheme.typography.titleMedium.copy(
                            fontWeight = FontWeight.Bold,
                            color = ZholdasTextPrimary
                        )
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = ZholdasTextPrimary
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = ZholdasBackground
                )
            )
        },
        containerColor = ZholdasBackground
    ) { innerPadding ->
        Column(
            modifier = modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            ModernCard {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("Фотография события", color = ZholdasTextSecondary, fontWeight = FontWeight.Bold)
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(160.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(ZholdasElevatedSurface)
                            .clickable(enabled = !isSubmitting) {
                                photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        val previewModel: Any? = selectedImageUri ?: event.imageURL?.takeIf { it.isNotBlank() }
                        if (previewModel != null) {
                            AsyncImage(
                                model = previewModel,
                                contentDescription = "Event cover",
                                contentScale = ContentScale.Crop,
                                modifier = Modifier.fillMaxSize()
                            )
                            Text(
                                if (selectedImageUri != null) "Новая фотография выбрана" else "Нажмите, чтобы заменить",
                                color = Color.White,
                                modifier = Modifier
                                    .clip(RoundedCornerShape(8.dp))
                                    .background(Color.Black.copy(alpha = 0.6f))
                                    .padding(10.dp)
                            )
                        } else {
                            Text("Выбрать фотографию", color = ZholdasAccent)
                        }
                    }
                    if (imageUploadError != null) {
                        Text(imageUploadError!!, color = ZholdasDanger)
                        Text("Нажмите «Сохранить» для повторной попытки", color = ZholdasTextSecondary)
                    }
                }
            }

            // Title section
            ModernCard {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "edit_ev_name".localized,
                        style = MaterialTheme.typography.labelMedium.copy(
                            fontWeight = FontWeight.Bold,
                            color = ZholdasTextSecondary
                        )
                    )
                    OutlinedTextField(
                        value = title,
                        onValueChange = { title = it },
                        placeholder = { Text("edit_ev_name_placeholder".localized, color = ZholdasTextSecondary) },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedTextColor = ZholdasTextPrimary,
                            unfocusedTextColor = ZholdasTextPrimary,
                            focusedBorderColor = ZholdasAccent,
                            unfocusedBorderColor = ZholdasBorder
                        )
                    )
                }
            }

            // Description section
            ModernCard {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "edit_ev_desc".localized,
                        style = MaterialTheme.typography.labelMedium.copy(
                            fontWeight = FontWeight.Bold,
                            color = ZholdasTextSecondary
                        )
                    )
                    OutlinedTextField(
                        value = description,
                        onValueChange = { description = it },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(110.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedTextColor = ZholdasTextPrimary,
                            unfocusedTextColor = ZholdasTextPrimary,
                            focusedBorderColor = ZholdasAccent,
                            unfocusedBorderColor = ZholdasBorder
                        )
                    )
                }
            }

            // Category section
            ModernCard {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "edit_ev_category".localized,
                        style = MaterialTheme.typography.labelMedium.copy(
                            fontWeight = FontWeight.Bold,
                            color = ZholdasTextSecondary
                        )
                    )

                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        categories.forEach { catKey ->
                            val isSelected = category == catKey
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(if (isSelected) ZholdasAccent else ZholdasElevatedSurface)
                                    .clickable { category = catKey }
                                    .padding(horizontal = 14.dp, vertical = 8.dp)
                            ) {
                                Text(
                                    text = catKey.localized,
                                    style = MaterialTheme.typography.bodySmall.copy(
                                        color = if (isSelected) Color.Black else ZholdasTextPrimary,
                                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
                                    )
                                )
                            }
                        }
                    }
                }
            }

            // Location & Coordinates section
            ModernCard {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(
                        text = "edit_ev_location".localized,
                        style = MaterialTheme.typography.labelMedium.copy(
                            fontWeight = FontWeight.Bold,
                            color = ZholdasTextSecondary
                        )
                    )
                    OutlinedTextField(
                        value = locationName,
                        onValueChange = { locationName = it },
                        placeholder = { Text("edit_ev_location_placeholder".localized, color = ZholdasTextSecondary) },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedTextColor = ZholdasTextPrimary,
                            unfocusedTextColor = ZholdasTextPrimary,
                            focusedBorderColor = ZholdasAccent,
                            unfocusedBorderColor = ZholdasBorder
                        )
                    )

                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        OutlinedTextField(
                            value = latitude,
                            onValueChange = { latitude = it },
                            label = { Text("edit_ev_latitude".localized, color = ZholdasTextSecondary) },
                            modifier = Modifier.weight(1f),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            singleLine = true,
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedTextColor = ZholdasTextPrimary,
                                unfocusedTextColor = ZholdasTextPrimary,
                                focusedBorderColor = ZholdasAccent,
                                unfocusedBorderColor = ZholdasBorder
                            )
                        )
                        OutlinedTextField(
                            value = longitude,
                            onValueChange = { longitude = it },
                            label = { Text("edit_ev_longitude".localized, color = ZholdasTextSecondary) },
                            modifier = Modifier.weight(1f),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            singleLine = true,
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedTextColor = ZholdasTextPrimary,
                                unfocusedTextColor = ZholdasTextPrimary,
                                focusedBorderColor = ZholdasAccent,
                                unfocusedBorderColor = ZholdasBorder
                            )
                        )
                    }
                }
            }

            // Max Participants Section
            ModernCard {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "edit_ev_max_participants".localized,
                        style = MaterialTheme.typography.bodyMedium.copy(
                            color = ZholdasTextPrimary,
                            fontWeight = FontWeight.Bold
                        )
                    )

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        IconButton(
                            onClick = { if (maxParticipants > 2) maxParticipants-- }
                        ) {
                            Icon(Icons.Default.Remove, contentDescription = "Decrease", tint = ZholdasAccent)
                        }
                        Text(
                            text = "$maxParticipants",
                            style = MaterialTheme.typography.titleMedium.copy(
                                color = ZholdasTextPrimary,
                                fontWeight = FontWeight.Bold
                            )
                        )
                        IconButton(
                            onClick = { if (maxParticipants < 100) maxParticipants++ }
                        ) {
                            Icon(Icons.Default.Add, contentDescription = "Increase", tint = ZholdasAccent)
                        }
                    }
                }
            }

            // Restrictions section
            ModernCard {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        text = "edit_ev_restrictions".localized,
                        style = MaterialTheme.typography.labelMedium.copy(
                            fontWeight = FontWeight.Bold,
                            color = ZholdasTextSecondary
                        )
                    )

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf(
                            "All" to "edit_ev_gender_all".localized,
                            "Men" to "edit_ev_gender_men".localized,
                            "Women" to "edit_ev_gender_women".localized
                        ).forEach { (valKey, label) ->
                            val isSel = genderFilter == valKey
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(if (isSel) ZholdasAccent else ZholdasElevatedSurface)
                                    .clickable { genderFilter = valKey }
                                    .padding(horizontal = 14.dp, vertical = 8.dp)
                            ) {
                                Text(
                                    text = label,
                                    style = MaterialTheme.typography.bodySmall.copy(
                                        color = if (isSel) Color.Black else ZholdasTextPrimary,
                                        fontWeight = if (isSel) FontWeight.Bold else FontWeight.Normal
                                    )
                                )
                            }
                        }
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        OutlinedTextField(
                            value = minAgeText,
                            onValueChange = { minAgeText = it },
                            label = { Text("edit_ev_age_from".localized, color = ZholdasTextSecondary) },
                            placeholder = { Text("18", color = ZholdasTextSecondary) },
                            modifier = Modifier.weight(1f),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            singleLine = true,
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedTextColor = ZholdasTextPrimary,
                                unfocusedTextColor = ZholdasTextPrimary,
                                focusedBorderColor = ZholdasAccent,
                                unfocusedBorderColor = ZholdasBorder
                            )
                        )
                        OutlinedTextField(
                            value = maxAgeText,
                            onValueChange = { maxAgeText = it },
                            label = { Text("edit_ev_age_to".localized, color = ZholdasTextSecondary) },
                            placeholder = { Text("60", color = ZholdasTextSecondary) },
                            modifier = Modifier.weight(1f),
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                            singleLine = true,
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedTextColor = ZholdasTextPrimary,
                                unfocusedTextColor = ZholdasTextPrimary,
                                focusedBorderColor = ZholdasAccent,
                                unfocusedBorderColor = ZholdasBorder
                            )
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            PrimaryButton(
                text = "edit_ev_save_btn".localized,
                onClick = {
                    if (title.isBlank() || locationName.isBlank()) {
                        Toast.makeText(context, "Заполните обязательные поля", Toast.LENGTH_SHORT).show()
                        return@PrimaryButton
                    }
                    val lat = latitude.toDoubleOrNull() ?: event.latitude
                    val lon = longitude.toDoubleOrNull() ?: event.longitude
                    val minAge = minAgeText.toIntOrNull()
                    val maxAge = maxAgeText.toIntOrNull()

                    coroutineScope.launch {
                        isSubmitting = true
                        imageUploadError = null
                        var uploadInProgress = selectedImageUri != null
                        try {
                            val uploadedUrl = selectedImageUri?.let {
                                EventImageUploader.upload(context.contentResolver, it, authViewModel.apiClient)
                            }
                            uploadInProgress = false
                            val finalImageUrl = EventImageUploader.imageUrlForUpdate(
                                existingUrl = event.imageURL,
                                uploadedUrl = uploadedUrl,
                                selectedNewImage = selectedImageUri != null
                            )
                            val request = CreateEventRequest(
                                title = title,
                                description = description,
                                category = category,
                                locationName = locationName,
                                latitude = lat,
                                longitude = lon,
                                startTime = event.startTime,
                                endTime = event.endTime,
                                maxParticipants = maxParticipants,
                                imageURL = finalImageUrl,
                                visibility = event.visibility,
                                genderFilter = genderFilter.takeIf { it != "All" },
                                minAge = minAge,
                                maxAge = maxAge
                            )
                            val updated = authViewModel.apiClient.apiService.updateEvent(event.id, request)
                            onSuccess(updated)
                        } catch (e: Exception) {
                            if (uploadInProgress) {
                                imageUploadError = e.message ?: "Не удалось загрузить фотографию. Повторите попытку."
                            }
                            Toast.makeText(context, e.message ?: "Error saving event", Toast.LENGTH_SHORT).show()
                        } finally {
                            isSubmitting = false
                        }
                    }
                },
                isLoading = isSubmitting
            )
        }
    }
}
