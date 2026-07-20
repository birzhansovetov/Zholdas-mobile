package com.example.zholdas.ui.screens.auth

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalContext
import com.example.zholdas.ZholdasApplication
import com.example.zholdas.data.local.Localization
import com.example.zholdas.data.local.localized
import com.example.zholdas.theme.*
import com.example.zholdas.ui.AuthViewModel
import com.example.zholdas.ui.components.ModernCard
import com.example.zholdas.ui.components.PrimaryButton
import com.example.zholdas.ui.components.modernFieldSurface
import kotlinx.coroutines.launch

@Composable
fun LoginScreen(
    authViewModel: AuthViewModel,
    onRegisterClick: () -> Unit,
    onForgotPasswordClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }

    var isEmailFocused by remember { mutableStateOf(false) }
    var isPasswordFocused by remember { mutableStateOf(false) }

    val isLoading by authViewModel.isLoading.collectAsState()
    val errorMessage by authViewModel.errorMessage.collectAsState()

    var showLanguageMenu by remember { mutableStateOf(false) }
    val preferences = (LocalContext.current.applicationContext as ZholdasApplication).preferences
    val settingsScope = rememberCoroutineScope()
    val selectLanguage: (String) -> Unit = { language ->
        Localization.language = language
        settingsScope.launch { preferences.setLanguage(language) }
        showLanguageMenu = false
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(ZholdasBackground)
    ) {
        // Scrollable Login Content
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(64.dp))

            // Logo & Header
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Neon Logo box representation
                Box(
                    modifier = Modifier
                        .size(86.dp)
                        .shadow(
                            elevation = 22.dp,
                            shape = RoundedCornerShape(20.dp),
                            ambientColor = ZholdasAccent.copy(alpha = 0.20f),
                            spotColor = ZholdasAccent.copy(alpha = 0.20f)
                        )
                        .clip(RoundedCornerShape(20.dp))
                        .background(ZholdasSurface)
                        .border(1.5.dp, ZholdasBorder, RoundedCornerShape(20.dp)),
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
                    text = "Жолдас",
                    color = ZholdasTextPrimary,
                    fontSize = 42.sp,
                    fontWeight = FontWeight.Black
                )

                Text(
                    text = "login_subtitle".localized,
                    color = ZholdasTextSecondary,
                    fontSize = 14.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }

            Spacer(modifier = Modifier.height(36.dp))

            // Input Fields Card
            ModernCard {
                // Email
                Column(
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = "login_email_label".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.sp
                    )

                    BasicTextField(
                        value = email,
                        onValueChange = { email = it },
                        modifier = Modifier
                            .onFocusChanged { isEmailFocused = it.isFocused }
                            .modernFieldSurface(isEmailFocused),
                        textStyle = TextStyle(
                            color = ZholdasTextPrimary,
                            fontSize = 16.sp
                        ),
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
                                            text = "user@example.com",
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

                // Password
                Column(
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = "login_password_label".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.sp
                    )

                    BasicTextField(
                        value = password,
                        onValueChange = { password = it },
                        modifier = Modifier
                            .onFocusChanged { isPasswordFocused = it.isFocused }
                            .modernFieldSurface(isPasswordFocused),
                        textStyle = TextStyle(
                            color = ZholdasTextPrimary,
                            fontSize = 16.sp
                        ),
                        cursorBrush = SolidColor(ZholdasAccent),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                        visualTransformation = PasswordVisualTransformation(),
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
                                            text = "login_password_placeholder".localized,
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
                
                Spacer(modifier = Modifier.height(10.dp))
                Text(
                    text = "login_forgot_password".localized,
                    color = ZholdasAccent,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .align(Alignment.End)
                        .clickable {
                            onForgotPasswordClick()
                        }
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Error Display
            if (errorMessage != null) {
                Text(
                    text = errorMessage!!,
                    color = ZholdasDanger,
                    fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
                Spacer(modifier = Modifier.height(16.dp))
            }

            // Sign In Button
            PrimaryButton(
                text = "login_btn".localized,
                onClick = {
                    authViewModel.signIn(email, password)
                },
                isLoading = isLoading,
                enabled = email.isNotEmpty() && password.isNotEmpty()
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Register Transition
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = "login_no_account".localized,
                    color = ZholdasTextSecondary,
                    fontSize = 14.sp
                )
                Text(
                    text = "login_register_link".localized,
                    color = ZholdasAccent,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.clickable { onRegisterClick() }
                )
            }
        }

        // Language Selector in Top Right (Floating)
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 16.dp, end = 16.dp)
        ) {
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(ZholdasPanel)
                    .border(1.dp, ZholdasBorder, RoundedCornerShape(8.dp))
                    .clickable { showLanguageMenu = true }
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = Localization.language.uppercase(),
                    color = ZholdasTextPrimary,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )
                Icon(
                    imageVector = Icons.Default.ArrowDropDown,
                    contentDescription = null,
                    tint = ZholdasTextSecondary,
                    modifier = Modifier.size(16.dp)
                )
            }

            DropdownMenu(
                expanded = showLanguageMenu,
                onDismissRequest = { showLanguageMenu = false },
                modifier = Modifier.background(ZholdasElevatedSurface)
            ) {
                DropdownMenuItem(
                    text = { Text("RU - Русский", color = ZholdasTextPrimary) },
                    onClick = {
                        selectLanguage("ru")
                    }
                )
                DropdownMenuItem(
                    text = { Text("KK - Қазақша", color = ZholdasTextPrimary) },
                    onClick = {
                        selectLanguage("kk")
                    }
                )
                DropdownMenuItem(
                    text = { Text("EN - English", color = ZholdasTextPrimary) },
                    onClick = {
                        selectLanguage("en")
                    }
                )
            }
        }
    }
}
