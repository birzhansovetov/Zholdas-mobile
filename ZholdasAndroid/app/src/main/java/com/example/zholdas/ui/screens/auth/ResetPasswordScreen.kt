package com.example.zholdas.ui.screens.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.example.zholdas.ui.AuthViewModel
import com.example.zholdas.ui.auth.PasswordResetLink
import kotlinx.coroutines.launch

@Composable
fun ResetPasswordScreen(
    link: PasswordResetLink,
    authViewModel: AuthViewModel,
    onFinished: () -> Unit
) {
    var password by remember { mutableStateOf("") }
    var confirmation by remember { mutableStateOf("") }
    var localError by remember { mutableStateOf<String?>(link.error) }
    var completed by remember { mutableStateOf(false) }
    val isLoading by authViewModel.isLoading.collectAsState()
    val serverError by authViewModel.errorMessage.collectAsState()
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Reset password", style = MaterialTheme.typography.headlineSmall)
        Spacer(Modifier.height(24.dp))
        if (completed) {
            Text("Password updated. You can now sign in with your new password.")
            Spacer(Modifier.height(20.dp))
            Button(onClick = onFinished) { Text("Back to sign in") }
            return@Column
        }
        if (!link.isValid) {
            Text(localError ?: "Invalid or expired password reset link", color = MaterialTheme.colorScheme.error)
            Spacer(Modifier.height(20.dp))
            Button(onClick = onFinished) { Text("Back to sign in") }
            return@Column
        }
        OutlinedTextField(
            value = password,
            onValueChange = { password = it; localError = null },
            label = { Text("New password") },
            visualTransformation = PasswordVisualTransformation(),
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            value = confirmation,
            onValueChange = { confirmation = it; localError = null },
            label = { Text("Confirm password") },
            visualTransformation = PasswordVisualTransformation(),
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        val visibleError = localError ?: serverError
        if (!visibleError.isNullOrBlank()) {
            Spacer(Modifier.height(12.dp))
            Text(visibleError, color = MaterialTheme.colorScheme.error)
        }
        Spacer(Modifier.height(20.dp))
        Button(
            enabled = !isLoading && password.isNotBlank() && confirmation.isNotBlank(),
            onClick = {
                localError = when {
                    password.length < 6 -> "Password must contain at least 6 characters"
                    password != confirmation -> "Passwords do not match"
                    else -> null
                }
                if (localError == null) scope.launch {
                    completed = authViewModel.resetPassword(link.accessToken!!, password)
                }
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            if (isLoading) CircularProgressIndicator(modifier = Modifier.height(20.dp))
            else Text("Update password")
        }
    }
}
