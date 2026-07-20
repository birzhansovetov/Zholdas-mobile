package com.example.zholdas.ui.screens.auth

import android.net.Uri
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.example.zholdas.data.local.localized
import com.example.zholdas.theme.*
import com.example.zholdas.ui.AuthViewModel
import com.example.zholdas.ui.components.ModernCard
import com.example.zholdas.ui.components.PrimaryButton
import com.example.zholdas.ui.components.modernFieldSurface
import java.util.Calendar

@Composable
fun RegisterScreen(
    authViewModel: AuthViewModel,
    onLoginClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current

    // Fields
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var fullName by remember { mutableStateOf("") }
    var bio by remember { mutableStateOf("") }

    // Steppers and selectors
    var selectedAge by remember { mutableStateOf(20) }
    var selectedGender by remember { mutableStateOf("Не указывать") } // "Мужской", "Женский", "Не указывать"
    var selectedAvatarPreset by remember { mutableStateOf("memoji_1") }
    var selectedPhotoUri by remember { mutableStateOf<Uri?>(null) }
    var selectedPhotoBytes by remember { mutableStateOf<ByteArray?>(null) }

    // Focus state
    var isFullNameFocused by remember { mutableStateOf(false) }
    var isEmailFocused by remember { mutableStateOf(false) }
    var isPasswordFocused by remember { mutableStateOf(false) }
    var isConfirmPasswordFocused by remember { mutableStateOf(false) }
    var isBioFocused by remember { mutableStateOf(false) }

    // Password visibility
    var showPassword by remember { mutableStateOf(false) }
    var showConfirmPassword by remember { mutableStateOf(false) }

    // Validation error
    var localError by remember { mutableStateOf<String?>(null) }

    val isLoading by authViewModel.isLoading.collectAsState()
    val errorMessage by authViewModel.errorMessage.collectAsState()

    val avatarPresets = listOf("memoji_1", "memoji_2", "memoji_3", "memoji_4", "memoji_5", "memoji_6")

    // Image Picker Launcher
    val imagePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        if (uri != null) {
            selectedPhotoUri = uri
            selectedAvatarPreset = ""
            try {
                context.contentResolver.openInputStream(uri)?.use { inputStream ->
                    selectedPhotoBytes = inputStream.readBytes()
                }
            } catch (e: Exception) {
                Log.e("RegisterScreen", "Failed to read image bytes: ${e.message}", e)
            }
        }
    }

    DisposableEffect(Unit) {
        authViewModel.clearError()
        onDispose {}
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(ZholdasBackground)
    ) {
        // Back Button
        Row(
            modifier = Modifier
                .statusBarsPadding()
                .padding(top = 16.dp, start = 16.dp)
                .clickable { onLoginClick() },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Icon(
                imageVector = Icons.Default.ArrowBack,
                contentDescription = null,
                tint = ZholdasAccent,
                modifier = Modifier.size(20.dp)
            )
            Text(
                text = "reg_back".localized,
                color = ZholdasAccent,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium
            )
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(72.dp))

            // Logo & Header
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(80.dp)
                        .shadow(
                            elevation = 16.dp,
                            shape = RoundedCornerShape(18.dp),
                            ambientColor = ZholdasAccent.copy(alpha = 0.35f),
                            spotColor = ZholdasAccent.copy(alpha = 0.35f)
                        )
                        .clip(RoundedCornerShape(18.dp))
                        .background(ZholdasSurface)
                        .border(1.5.dp, ZholdasBorder, RoundedCornerShape(18.dp)),
                    contentAlignment = Alignment.Center
                ) {
                    Image(
                        painter = painterResource(id = com.example.zholdas.R.drawable.logo),
                        contentDescription = "Logo",
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                }

                Text(
                    text = "reg_title_create".localized,
                    color = ZholdasTextPrimary,
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Main Inputs Card
            ModernCard {
                // 1. Avatar Picker
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "reg_choose_avatar".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.5.sp
                    )

                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)
                    ) {
                        // Custom Photo Picker Button
                        item {
                            Box(
                                modifier = Modifier
                                    .size(50.dp)
                                    .clip(CircleShape)
                                    .background(Color.White.copy(alpha = 0.05f))
                                    .border(
                                        width = 2.dp,
                                        color = if (selectedPhotoUri != null) ZholdasAccent else Color.White.copy(alpha = 0.1f),
                                        shape = CircleShape
                                    )
                                    .clickable { imagePickerLauncher.launch("image/*") },
                                contentAlignment = Alignment.Center
                            ) {
                                if (selectedPhotoUri != null) {
                                    AsyncImage(
                                        model = selectedPhotoUri,
                                        contentDescription = null,
                                        modifier = Modifier.fillMaxSize().clip(CircleShape),
                                        contentScale = ContentScale.Crop
                                    )
                                } else {
                                    Icon(
                                        imageVector = Icons.Default.Add,
                                        contentDescription = null,
                                        tint = ZholdasAccent,
                                        modifier = Modifier.size(24.dp)
                                    )
                                }
                            }
                        }

                        // Presets
                        items(avatarPresets) { preset ->
                            val resId = when (preset) {
                                "memoji_1" -> com.example.zholdas.R.drawable.memoji_1
                                "memoji_2" -> com.example.zholdas.R.drawable.memoji_2
                                "memoji_3" -> com.example.zholdas.R.drawable.memoji_3
                                "memoji_4" -> com.example.zholdas.R.drawable.memoji_4
                                "memoji_5" -> com.example.zholdas.R.drawable.memoji_5
                                "memoji_6" -> com.example.zholdas.R.drawable.memoji_6
                                else -> 0
                            }

                            val isSelected = selectedAvatarPreset == preset
                            Box(
                                modifier = Modifier
                                    .size(50.dp)
                                    .clip(CircleShape)
                                    .background(if (isSelected) ZholdasAccent.copy(alpha = 0.2f) else Color.White.copy(alpha = 0.05f))
                                    .border(
                                        width = 2.dp,
                                        color = if (isSelected) ZholdasAccent else Color.White.copy(alpha = 0.1f),
                                        shape = CircleShape
                                    )
                                    .clickable {
                                        selectedAvatarPreset = preset
                                        selectedPhotoUri = null
                                        selectedPhotoBytes = null
                                    },
                                contentAlignment = Alignment.Center
                            ) {
                                if (resId != 0) {
                                    Image(
                                        painter = painterResource(id = resId),
                                        contentDescription = null,
                                        modifier = Modifier.fillMaxSize().clip(CircleShape),
                                        contentScale = ContentScale.Crop
                                    )
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(18.dp))

                // 2. Full Name
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "reg_name_label".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.5.sp
                    )

                    BasicTextField(
                        value = fullName,
                        onValueChange = { fullName = it },
                        modifier = Modifier
                            .onFocusChanged { isFullNameFocused = it.isFocused }
                            .modernFieldSurface(isFullNameFocused),
                        textStyle = TextStyle(color = ZholdasTextPrimary, fontSize = 16.sp),
                        cursorBrush = SolidColor(ZholdasAccent),
                        singleLine = true,
                        decorationBox = { innerTextField ->
                            Row(
                                modifier = Modifier.fillMaxSize(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Person,
                                    contentDescription = null,
                                    tint = if (isFullNameFocused) ZholdasAccent else ZholdasTextSecondary,
                                    modifier = Modifier.size(24.dp)
                                )
                                Box(modifier = Modifier.weight(1f)) {
                                    if (fullName.isEmpty()) {
                                        Text(
                                            text = "reg_name_placeholder".localized,
                                            color = ZholdasTextTertiary,
                                            fontSize = 16.sp
                                        )
                                    }
                                    innerTextField()
                                }
                            }
                        }
                    )
                }

                Spacer(modifier = Modifier.height(18.dp))

                // 3. Email
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "reg_email_label".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.5.sp
                    )

                    BasicTextField(
                        value = email,
                        onValueChange = { email = it },
                        modifier = Modifier
                            .onFocusChanged { isEmailFocused = it.isFocused }
                            .modernFieldSurface(isEmailFocused),
                        textStyle = TextStyle(color = ZholdasTextPrimary, fontSize = 16.sp),
                        cursorBrush = SolidColor(ZholdasAccent),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                        singleLine = true,
                        decorationBox = { innerTextField ->
                            Row(
                                modifier = Modifier.fillMaxSize(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Email,
                                    contentDescription = null,
                                    tint = if (isEmailFocused) ZholdasAccent else ZholdasTextSecondary,
                                    modifier = Modifier.size(24.dp)
                                )
                                Box(modifier = Modifier.weight(1f)) {
                                    if (email.isEmpty()) {
                                        Text(
                                            text = "reg_email_placeholder".localized,
                                            color = ZholdasTextTertiary,
                                            fontSize = 16.sp
                                        )
                                    }
                                    innerTextField()
                                }
                            }
                        }
                    )
                }

                Spacer(modifier = Modifier.height(18.dp))

                // 4. Password
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "reg_password_label".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.5.sp
                    )

                    BasicTextField(
                        value = password,
                        onValueChange = { password = it },
                        modifier = Modifier
                            .onFocusChanged { isPasswordFocused = it.isFocused }
                            .modernFieldSurface(isPasswordFocused),
                        textStyle = TextStyle(color = ZholdasTextPrimary, fontSize = 16.sp),
                        cursorBrush = SolidColor(ZholdasAccent),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                        visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                        singleLine = true,
                        decorationBox = { innerTextField ->
                            Row(
                                modifier = Modifier.fillMaxSize(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Lock,
                                    contentDescription = null,
                                    tint = if (isPasswordFocused) ZholdasAccent else ZholdasTextSecondary,
                                    modifier = Modifier.size(24.dp)
                                )
                                Box(modifier = Modifier.weight(1f)) {
                                    if (password.isEmpty()) {
                                        Text(
                                            text = "reg_password_placeholder".localized,
                                            color = ZholdasTextTertiary,
                                            fontSize = 16.sp
                                        )
                                    }
                                    innerTextField()
                                }
                                Text(
                                    text = if (showPassword) "reg_hide".localized else "reg_show".localized,
                                    color = ZholdasAccent,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    modifier = Modifier.clickable { showPassword = !showPassword }
                                )
                            }
                        }
                    )
                }

                Spacer(modifier = Modifier.height(18.dp))

                // 5. Confirm Password
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "reg_confirm_password_label".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.5.sp
                    )

                    BasicTextField(
                        value = confirmPassword,
                        onValueChange = { confirmPassword = it },
                        modifier = Modifier
                            .onFocusChanged { isConfirmPasswordFocused = it.isFocused }
                            .modernFieldSurface(isConfirmPasswordFocused),
                        textStyle = TextStyle(color = ZholdasTextPrimary, fontSize = 16.sp),
                        cursorBrush = SolidColor(ZholdasAccent),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                        visualTransformation = if (showConfirmPassword) VisualTransformation.None else PasswordVisualTransformation(),
                        singleLine = true,
                        decorationBox = { innerTextField ->
                            Row(
                                modifier = Modifier.fillMaxSize(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.LockClock,
                                    contentDescription = null,
                                    tint = if (isConfirmPasswordFocused) ZholdasAccent else ZholdasTextSecondary,
                                    modifier = Modifier.size(24.dp)
                                )
                                Box(modifier = Modifier.weight(1f)) {
                                    if (confirmPassword.isEmpty()) {
                                        Text(
                                            text = "********",
                                            color = ZholdasTextTertiary,
                                            fontSize = 16.sp
                                        )
                                    }
                                    innerTextField()
                                }
                                Text(
                                    text = if (showConfirmPassword) "reg_hide".localized else "reg_show".localized,
                                    color = ZholdasAccent,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    modifier = Modifier.clickable { showConfirmPassword = !showConfirmPassword }
                                )
                            }
                        }
                    )
                }

                Spacer(modifier = Modifier.height(18.dp))

                // 6. Gender Selector
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "reg_gender_label".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.5.sp
                    )

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        val genders = listOf(
                            Triple("Мужской", "reg_gender_male", com.example.zholdas.R.drawable.gender_male),
                            Triple("Женский", "reg_gender_female", com.example.zholdas.R.drawable.gender_female),
                            Triple("Не указывать", "reg_gender_none", com.example.zholdas.R.drawable.gender_other)
                        )

                        genders.forEach { (genderKey, genderLabel, drawableRes) ->
                            val isSelected = selectedGender == genderKey
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(if (isSelected) Color.White.copy(alpha = 0.1f) else Color.White.copy(alpha = 0.04f))
                                    .border(
                                        width = if (isSelected) 2.dp else 1.dp,
                                        color = if (isSelected) ZholdasAccent else Color.White.copy(alpha = 0.06f),
                                        shape = RoundedCornerShape(12.dp)
                                    )
                                    .clickable { selectedGender = genderKey }
                                    .padding(vertical = 12.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Column(
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    verticalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    Image(
                                        painter = painterResource(id = drawableRes),
                                        contentDescription = null,
                                        modifier = Modifier
                                            .size(36.dp)
                                            .clip(CircleShape)
                                    )
                                    Text(
                                        text = genderLabel.localized,
                                        color = if (isSelected) Color.White else Color.Gray,
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(18.dp))

                // 7. Age Picker (Stepper)
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "reg_birth_year_label".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.5.sp
                    )

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .modernFieldSurface(false)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Cake,
                            contentDescription = null,
                            tint = ZholdasAccent,
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Text(
                            text = "$selectedAge",
                            color = Color.White,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "reg_age_suffix".localized,
                            color = Color.Gray,
                            fontSize = 14.sp
                        )

                        Spacer(modifier = Modifier.weight(1f))

                        // Custom Stepper representation
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(Color.White.copy(alpha = 0.05f))
                                .border(1.dp, ZholdasBorder, RoundedCornerShape(8.dp))
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(width = 40.dp, height = 36.dp)
                                    .clickable(enabled = selectedAge > 13) { selectedAge-- },
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = "-",
                                    color = if (selectedAge > 13) Color.White else Color.Gray,
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                            Box(modifier = Modifier.width(1.dp).height(20.dp).background(ZholdasBorder))
                            Box(
                                modifier = Modifier
                                    .size(width = 40.dp, height = 36.dp)
                                    .clickable(enabled = selectedAge < 80) { selectedAge++ },
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = "+",
                                    color = if (selectedAge < 80) Color.White else Color.Gray,
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(18.dp))

                // 8. About Me (Bio)
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "reg_bio_label".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.5.sp
                    )

                    BasicTextField(
                        value = bio,
                        onValueChange = { bio = it },
                        modifier = Modifier
                            .onFocusChanged { isBioFocused = it.isFocused }
                            .modernFieldSurface(isBioFocused),
                        textStyle = TextStyle(color = ZholdasTextPrimary, fontSize = 16.sp),
                        cursorBrush = SolidColor(ZholdasAccent),
                        singleLine = true,
                        decorationBox = { innerTextField ->
                            Row(
                                modifier = Modifier.fillMaxSize(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Comment,
                                    contentDescription = null,
                                    tint = if (isBioFocused) ZholdasAccent else ZholdasTextSecondary,
                                    modifier = Modifier.size(24.dp)
                                )
                                Box(modifier = Modifier.weight(1f)) {
                                    if (bio.isEmpty()) {
                                        Text(
                                            text = "reg_bio_placeholder".localized,
                                            color = ZholdasTextTertiary,
                                            fontSize = 16.sp
                                        )
                                    }
                                    innerTextField()
                                }
                            }
                        }
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // 9. Live Preview Card
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(ZholdasElevatedSurface.copy(alpha = 0.5f))
                    .border(1.dp, ZholdasBorder, RoundedCornerShape(16.dp))
                    .padding(16.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    // Avatar display
                    Box(
                        modifier = Modifier
                            .size(60.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.1f))
                            .border(1.dp, Color.White.copy(alpha = 0.15f), CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                        if (selectedPhotoUri != null) {
                            AsyncImage(
                                model = selectedPhotoUri,
                                contentDescription = null,
                                modifier = Modifier.fillMaxSize().clip(CircleShape),
                                contentScale = ContentScale.Crop
                            )
                        } else {
                            val resId = when (selectedAvatarPreset) {
                                "memoji_1" -> com.example.zholdas.R.drawable.memoji_1
                                "memoji_2" -> com.example.zholdas.R.drawable.memoji_2
                                "memoji_3" -> com.example.zholdas.R.drawable.memoji_3
                                "memoji_4" -> com.example.zholdas.R.drawable.memoji_4
                                "memoji_5" -> com.example.zholdas.R.drawable.memoji_5
                                "memoji_6" -> com.example.zholdas.R.drawable.memoji_6
                                else -> com.example.zholdas.R.drawable.memoji_1
                            }
                            Image(
                                painter = painterResource(id = resId),
                                contentDescription = null,
                                modifier = Modifier.fillMaxSize().clip(CircleShape),
                                contentScale = ContentScale.Crop
                            )
                        }
                    }

                    // Text fields
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            text = if (fullName.isEmpty()) "reg_preview_name".localized else fullName,
                            color = Color.White,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = if (email.isEmpty()) "email@example.com" else email,
                            color = Color.Gray,
                            fontSize = 14.sp
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Error Display
            val activeError = localError ?: errorMessage
            if (activeError != null) {
                Text(
                    text = activeError,
                    color = ZholdasDanger,
                    fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
                Spacer(modifier = Modifier.height(16.dp))
            }

            // Register Button
            PrimaryButton(
                text = "register_btn".localized,
                onClick = {
                    if (password != confirmPassword) {
                        localError = "reg_err_mismatch".localized
                    } else if (password.length < 6) {
                        localError = "reg_err_short".localized
                    } else {
                        localError = null
                        val username = email.substringBefore("@")
                        val avatarURL = if (selectedPhotoUri != null) "" else "asset:$selectedAvatarPreset"
                        
                        val currentYear = Calendar.getInstance().get(Calendar.YEAR)
                        val birthYear = currentYear - selectedAge
                        val formattedBio = "[gender:$selectedGender][birth_year:$birthYear]$bio"

                        authViewModel.signUp(
                            email = email,
                            password = password,
                            username = username,
                            fullName = fullName,
                            avatarURL = avatarURL,
                            bio = formattedBio,
                            city = "Алматы",
                            photoData = selectedPhotoBytes
                        )
                    }
                },
                isLoading = isLoading,
                enabled = email.isNotEmpty() && password.isNotEmpty() && confirmPassword.isNotEmpty() && fullName.isNotEmpty()
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Login Transition link
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = "register_have_account".localized,
                    color = ZholdasTextSecondary,
                    fontSize = 14.sp
                )
                Text(
                    text = "register_login_link".localized,
                    color = ZholdasAccent,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.clickable { onLoginClick() }
                )
            }
        }
    }
}
