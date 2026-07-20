package com.example.zholdas.ui.screens.profile

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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalContext
import coil.compose.AsyncImage
import com.example.zholdas.data.local.localized
import com.example.zholdas.theme.*
import com.example.zholdas.ui.AuthViewModel
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditProfileScreen(
    authViewModel: AuthViewModel,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    val currentUserProfile by authViewModel.currentUserProfile.collectAsState()
    val errorMessage by authViewModel.errorMessage.collectAsState()
    val scope = rememberCoroutineScope()

    var fullName by remember { mutableStateOf("") }
    var bio by remember { mutableStateOf("") }
    var city by remember { mutableStateOf("Алматы") }
    var avatarURL by remember { mutableStateOf("") }
    var selectedAvatarUri by remember { mutableStateOf<Uri?>(null) }
    var isSaving by remember { mutableStateOf(false) }
    var cityExpanded by remember { mutableStateOf(false) }

    val context = LocalContext.current
    val photoPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri -> selectedAvatarUri = uri }

    val cities = listOf("Алматы", "Астана", "Шымкент", "Караганда")

    LaunchedEffect(currentUserProfile) {
        currentUserProfile?.let { profile ->
            fullName = profile.fullName
            bio = profile.bio ?: ""
            city = profile.city ?: "Алматы"
            avatarURL = profile.avatarURL ?: ""
        }
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
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                TextButton(onClick = { onDismiss() }) {
                    Text(
                        text = "btn_cancel".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 16.sp
                    )
                }

                Text(
                    text = "edit_prof_title".localized,
                    color = ZholdasTextPrimary,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )

                TextButton(
                    onClick = {
                        if (fullName.trim().isNotEmpty() && !isSaving) {
                            scope.launch {
                                isSaving = true
                                val finalAvatarURL = if (selectedAvatarUri != null) {
                                    authViewModel.uploadProfileImage(context.contentResolver, selectedAvatarUri!!)
                                } else avatarURL
                                if (selectedAvatarUri != null && finalAvatarURL == null) {
                                    isSaving = false
                                    return@launch
                                }
                                val success = authViewModel.updateUserProfile(
                                    fullName = fullName.trim(),
                                    bio = bio.trim(),
                                    city = city,
                                    avatarURL = finalAvatarURL.orEmpty().trim()
                                )
                                isSaving = false
                                if (success) {
                                    onDismiss()
                                }
                            }
                        }
                    },
                    enabled = fullName.trim().isNotEmpty() && !isSaving
                ) {
                    Text(
                        text = "btn_done".localized,
                        color = if (fullName.trim().isNotEmpty()) ZholdasAccent else ZholdasTextTertiary,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            Divider(color = ZholdasBorder)

            ScrollViewContent(
                fullName = fullName,
                onFullNameChange = { fullName = it },
                city = city,
                onCityChange = { city = it },
                cityExpanded = cityExpanded,
                onCityExpandedChange = { cityExpanded = it },
                cities = cities,
                bio = bio,
                onBioChange = { bio = it },
                avatarURL = avatarURL,
                selectedAvatarUri = selectedAvatarUri,
                onChooseAvatar = {
                    photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                },
                errorMessage = errorMessage,
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
            )
        }

        // Saving Overlay
        if (isSaving) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.4f)),
                contentAlignment = Alignment.Center
            ) {
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color(0xFF262B38))
                        .padding(horizontal = 24.dp, vertical = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    CircularProgressIndicator(
                        color = ZholdasAccent,
                        modifier = Modifier.size(24.dp),
                        strokeWidth = 2.5.dp
                    )
                    Text(
                        text = "edit_prof_saving".localized,
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
        }
    }
}

@Composable
private fun ScrollViewContent(
    fullName: String,
    onFullNameChange: (String) -> Unit,
    city: String,
    onCityChange: (String) -> Unit,
    cityExpanded: Boolean,
    onCityExpandedChange: (Boolean) -> Unit,
    cities: List<String>,
    bio: String,
    onBioChange: (String) -> Unit,
    avatarURL: String,
    selectedAvatarUri: Uri?,
    onChooseAvatar: () -> Unit,
    errorMessage: String?,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(28.dp)
    ) {
        // Avatar Preview Section
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(90.dp)
                    .shadow(8.dp, CircleShape, ambientColor = Color.Black.copy(alpha = 0.3f), spotColor = Color.Black.copy(alpha = 0.3f))
                    .clip(CircleShape)
                    .background(
                        brush = Brush.linearGradient(
                            colors = listOf(
                                Color(0xFF402673),
                                Color(0xFF261440)
                            )
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                if (selectedAvatarUri != null || avatarURL.isNotEmpty()) {
                    AsyncImage(
                        model = selectedAvatarUri ?: avatarURL,
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .size(90.dp)
                            .clip(CircleShape)
                    )
                } else {
                    Text(
                        text = getInitials(fullName),
                        color = Color.White,
                        fontSize = 32.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            Text(
                text = "edit_prof_preview".localized,
                color = ZholdasTextSecondary,
                fontSize = 12.sp
            )
            OutlinedButton(onClick = onChooseAvatar) {
                Text("Choose photo", color = ZholdasAccent)
            }
        }

        // Input Fields
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // Full Name Input
            InputField(
                title = "edit_prof_name_title".localized,
                text = fullName,
                onTextChange = onFullNameChange,
                placeholder = "edit_prof_name_placeholder".localized
            )

            // City Picker Field
            CityPickerField(
                city = city,
                onCityChange = onCityChange,
                expanded = cityExpanded,
                onExpandedChange = onCityExpandedChange,
                cities = cities
            )

            // Bio Field
            BioField(
                text = bio,
                onTextChange = onBioChange
            )

        }

        if (!errorMessage.isNullOrEmpty()) {
            Text(
                text = "?? $errorMessage",
                color = ZholdasDanger,
                fontSize = 14.sp,
                modifier = Modifier.padding(horizontal = 24.dp)
            )
        }
    }
}

@Composable
private fun InputField(
    title: String,
    text: String,
    onTextChange: (String) -> Unit,
    placeholder: String
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Text(
            text = title,
            color = ZholdasTextSecondary,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.5.sp
        )

        OutlinedTextField(
            value = text,
            onValueChange = onTextChange,
            placeholder = {
                Text(
                    text = placeholder,
                    color = ZholdasTextTertiary
                )
            },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = ZholdasTextPrimary,
                unfocusedTextColor = ZholdasTextPrimary,
                focusedContainerColor = ZholdasSurface,
                unfocusedContainerColor = ZholdasSurface,
                focusedBorderColor = ZholdasAccent,
                unfocusedBorderColor = ZholdasBorder
            ),
            singleLine = true
        )
    }
}

@Composable
private fun CityPickerField(
    city: String,
    onCityChange: (String) -> Unit,
    expanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    cities: List<String>
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Text(
            text = "edit_prof_city_title".localized,
            color = ZholdasTextSecondary,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.5.sp
        )

        Box(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(ZholdasSurface)
                    .border(1.dp, ZholdasBorder, RoundedCornerShape(12.dp))
                    .clickable { onExpandedChange(true) }
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = if (city.isEmpty()) "edit_prof_city_placeholder".localized else city,
                    color = if (city.isEmpty()) ZholdasTextTertiary else ZholdasTextPrimary,
                    fontSize = 16.sp
                )
                Icon(
                    imageVector = Icons.Default.ArrowDropDown,
                    contentDescription = null,
                    tint = ZholdasTextSecondary
                )
            }

            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { onExpandedChange(false) },
                modifier = Modifier.background(ZholdasElevatedSurface)
            ) {
                cities.forEach { option ->
                    DropdownMenuItem(
                        text = {
                            Text(text = option, color = ZholdasTextPrimary)
                        },
                        onClick = {
                            onCityChange(option)
                            onExpandedChange(false)
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun BioField(
    text: String,
    onTextChange: (String) -> Unit
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Text(
            text = "reg_bio_label".localized,
            color = ZholdasTextSecondary,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.5.sp
        )

        OutlinedTextField(
            value = text,
            onValueChange = onTextChange,
            placeholder = {
                Text(
                    text = "edit_prof_bio_placeholder".localized,
                    color = ZholdasTextTertiary
                )
            },
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 120.dp),
            shape = RoundedCornerShape(12.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = ZholdasTextPrimary,
                unfocusedTextColor = ZholdasTextPrimary,
                focusedContainerColor = ZholdasSurface,
                unfocusedContainerColor = ZholdasSurface,
                focusedBorderColor = ZholdasAccent,
                unfocusedBorderColor = ZholdasBorder
            ),
            minLines = 4,
            maxLines = 8
        )
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
