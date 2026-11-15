package com.example.zholdas.ui.screens.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.zholdas.data.local.localized
import com.example.zholdas.theme.*
import com.example.zholdas.ui.AuthUseCases
import com.example.zholdas.ui.AuthViewModel
import com.example.zholdas.ui.components.ModernCard
import com.example.zholdas.ui.components.PrimaryButton
import com.example.zholdas.ui.components.modernFieldSurface
import kotlinx.coroutines.delay

@Composable
fun VerifyEmailScreen(
    authViewModel: AuthViewModel,
    onBackClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    var code by rememberSaveable { mutableStateOf("") }
    var isCodeFocused by remember { mutableStateOf(false) }
    var secondsRemaining by rememberSaveable { mutableIntStateOf(60) }

    val email by authViewModel.pendingVerificationEmail.collectAsState()
    val isLoading by authViewModel.isLoading.collectAsState()
    val errorMessage by authViewModel.errorMessage.collectAsState()
    val infoMessage by authViewModel.infoMessage.collectAsState()

    DisposableEffect(Unit) {
        authViewModel.clearError()
        authViewModel.clearInfoMessage()
        onDispose {}
    }

    LaunchedEffect(secondsRemaining) {
        if (secondsRemaining > 0) {
            delay(1000L)
            secondsRemaining--
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(ZholdasBackground)
    ) {
        // Back Button (Изменить email)
        Row(
            modifier = Modifier
                .statusBarsPadding()
                .padding(top = 16.dp, start = 16.dp)
                .clickable {
                    authViewModel.cancelPendingVerification()
                    onBackClick()
                },
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
                text = "verify_email_change".localized,
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
            Spacer(modifier = Modifier.height(100.dp))

            // Header Title
            Text(
                text = "verify_email_title".localized,
                color = ZholdasTextPrimary,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Header Subtitle: Мы отправили 6-значный код на <email>
            Text(
                text = String.format("verify_email_subtitle_format".localized, email ?: ""),
                color = ZholdasTextSecondary,
                fontSize = 14.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 16.dp)
            )

            Spacer(modifier = Modifier.height(36.dp))

            // Input Card
            ModernCard {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        text = "verify_email_code_label".localized,
                        color = ZholdasTextSecondary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.sp
                    )

                    BasicTextField(
                        value = code,
                        onValueChange = { input ->
                            code = AuthUseCases.cleanVerificationCode(input)
                        },
                        modifier = Modifier
                            .onFocusChanged { isCodeFocused = it.isFocused }
                            .modernFieldSurface(isCodeFocused),
                        textStyle = TextStyle(
                            color = ZholdasTextPrimary,
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 6.sp,
                            textAlign = TextAlign.Center
                        ),
                        cursorBrush = SolidColor(ZholdasAccent),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
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
                                    tint = if (isCodeFocused) ZholdasAccent else ZholdasTextSecondary,
                                    modifier = Modifier.size(24.dp)
                                )
                                Box(
                                    modifier = Modifier.weight(1f),
                                    contentAlignment = Alignment.CenterStart
                                ) {
                                    if (code.isEmpty()) {
                                        Text(
                                            text = "••••••",
                                            color = ZholdasTextTertiary,
                                            fontSize = 20.sp,
                                            letterSpacing = 6.sp
                                        )
                                    }
                                    innerTextField()
                                }
                            }
                        }
                    )
                }
            }

            Spacer(modifier = Modifier.height(20.dp))

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

            // Info Display (например, "Код отправлен повторно")
            if (infoMessage != null) {
                Text(
                    text = infoMessage!!,
                    color = ZholdasSuccess,
                    fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
                Spacer(modifier = Modifier.height(16.dp))
            }

            // Primary Confirm Button
            PrimaryButton(
                text = "verify_email_confirm".localized,
                onClick = {
                    authViewModel.verifySignupCode(code)
                },
                isLoading = isLoading,
                enabled = code.length == 6 && !isLoading
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Resend Code Button with 60-second Countdown
            val canResend = secondsRemaining == 0 && !isLoading
            val resendText = if (secondsRemaining > 0) {
                String.format("verify_email_resend_in_format".localized, secondsRemaining)
            } else {
                "verify_email_resend".localized
            }

            Text(
                text = resendText,
                color = if (canResend) ZholdasAccent else ZholdasTextTertiary,
                fontSize = 14.sp,
                fontWeight = if (canResend) FontWeight.Bold else FontWeight.Normal,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .padding(vertical = 8.dp)
                    .clickable(enabled = canResend) {
                        authViewModel.resendSignupCode()
                        secondsRemaining = 60
                    }
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Change Email Link
            Text(
                text = "verify_email_change".localized,
                color = ZholdasTextSecondary,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .padding(vertical = 8.dp)
                    .clickable {
                        authViewModel.cancelPendingVerification()
                        onBackClick()
                    }
            )
        }
    }
}
