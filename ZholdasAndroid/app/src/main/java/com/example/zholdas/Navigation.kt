package com.example.zholdas

import androidx.compose.runtime.Composable
import androidx.navigation3.runtime.entryProvider
import androidx.navigation3.runtime.rememberNavBackStack
import androidx.navigation3.ui.NavDisplay
import com.example.zholdas.ui.AuthViewModel
import com.example.zholdas.ui.screens.auth.LoginScreen
import com.example.zholdas.ui.screens.auth.RegisterScreen
import com.example.zholdas.ui.screens.auth.ForgotPasswordScreen

@Composable
fun AuthNavigation(authViewModel: AuthViewModel) {
    val backStack = rememberNavBackStack(Login)

    NavDisplay(
        backStack = backStack,
        onBack = { backStack.removeLastOrNull() },
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
        }
    )
}
