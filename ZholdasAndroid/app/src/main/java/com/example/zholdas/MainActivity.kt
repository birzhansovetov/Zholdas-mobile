package com.example.zholdas

import android.Manifest
import android.content.Intent
import android.os.Bundle
import android.os.Build
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.zholdas.theme.ZholdasTheme
import com.example.zholdas.ui.AuthViewModel
import com.example.zholdas.ui.main.MainAppShell
import com.example.zholdas.data.local.AppTheme
import com.example.zholdas.data.local.Localization
import com.example.zholdas.ui.auth.PasswordResetDeepLink
import com.example.zholdas.ui.auth.PasswordResetLink
import com.example.zholdas.ui.screens.auth.ResetPasswordScreen

class MainActivity : ComponentActivity() {
    private val passwordResetLink = mutableStateOf<PasswordResetLink?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        passwordResetLink.value = PasswordResetDeepLink.parse(intent?.dataString)
        
        enableEdgeToEdge()
        
        val app = application as ZholdasApplication
        val authViewModelFactory = AuthViewModel.Factory(app.container)

        setContent {
            val authViewModel: AuthViewModel = viewModel(factory = authViewModelFactory)
            val isAuthenticated by authViewModel.isAuthenticated.collectAsState()
            val language by app.preferences.language.collectAsState(initial = "ru")
            val theme by app.preferences.theme.collectAsState(initial = AppTheme.SYSTEM)
            val useDarkTheme = when (theme) {
                AppTheme.SYSTEM -> isSystemInDarkTheme()
                AppTheme.LIGHT -> false
                AppTheme.DARK -> true
            }
            val notificationPermissionLauncher = rememberLauncherForActivityResult(
                ActivityResultContracts.RequestPermission()
            ) { }
            val context = LocalContext.current

            LaunchedEffect(language) { Localization.language = language }
            LaunchedEffect(isAuthenticated) {
                if (isAuthenticated && Build.VERSION.SDK_INT >= 33 &&
                    ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
                    PackageManager.PERMISSION_GRANTED
                ) {
                    notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
            }

            ZholdasTheme(darkTheme = useDarkTheme) {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    val resetLink = passwordResetLink.value
                    if (resetLink != null) {
                        ResetPasswordScreen(
                            link = resetLink,
                            authViewModel = authViewModel,
                            onFinished = { passwordResetLink.value = null }
                        )
                    } else if (isAuthenticated) {
                        MainAppShell(authViewModel)
                    } else {
                        AuthNavigation(authViewModel)
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        PasswordResetDeepLink.parse(intent.dataString)?.let { passwordResetLink.value = it }
    }
}
