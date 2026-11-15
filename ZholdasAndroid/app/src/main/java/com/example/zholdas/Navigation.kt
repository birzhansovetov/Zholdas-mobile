package com.example.zholdas

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.navigation3.runtime.entryProvider
import androidx.navigation3.runtime.rememberNavBackStack
import androidx.navigation3.ui.NavDisplay
import com.example.zholdas.ui.AuthViewModel
import com.example.zholdas.ui.screens.auth.LoginScreen
import com.example.zholdas.ui.screens.auth.RegisterScreen
import com.example.zholdas.ui.screens.auth.ForgotPasswordScreen
import com.example.zholdas.ui.screens.auth.VerifyEmailScreen

@Composable
fun AuthNavigation(authViewModel: AuthViewModel) {
    val backStack = rememberNavBackStack(Login)
    val pendingEmail by authViewModel.pendingVerificationEmail.collectAsState()
    val isAuthenticated by authViewModel.isAuthenticated.collectAsState()

    LaunchedEffect(pendingEmail, isAuthenticated) {
        if (pendingEmail != null && !isAuthenticated) {
            if (!backStack.contains(VerifyEmail)) {
                backStack.add(VerifyEmail)
            }
        } else if (pendingEmail == null && !isAuthenticated) {
            if (backStack.contains(VerifyEmail)) {
                backStack.remove(VerifyEmail)
            }
        }
    }

    NavDisplay(
        backStack = backStack,
        onBack = {
            if (backStack.lastOrNull() == VerifyEmail) {
                authViewModel.cancelPendingVerification()
            }
            backStack.removeLastOrNull()
        },
        entryProvider = entryProvider {
            entry<Login> {
                LoginScreen(
                    authViewModel = authViewModel,
                    onRegisterClick = { backStack.add(Register) },
                    onForgotPasswordClick = { backStack.add(ForgotPassword) }
                )
            }
            entry<Register> {
                RegisterScreen(
                    authViewModel = authViewModel,
                    onLoginClick = { backStack.removeLastOrNull() }
                )
            }
            entry<ForgotPassword> {
                ForgotPasswordScreen(
                    authViewModel = authViewModel,
                    onBackClick = { backStack.removeLastOrNull() }
                )
            }
            entry<VerifyEmail> {
                VerifyEmailScreen(
                    authViewModel = authViewModel,
                    onBackClick = {
                        authViewModel.cancelPendingVerification()
                        if (backStack.contains(VerifyEmail)) {
                            backStack.remove(VerifyEmail)
                        }
                    }
                )
            }
        }
    )
}

