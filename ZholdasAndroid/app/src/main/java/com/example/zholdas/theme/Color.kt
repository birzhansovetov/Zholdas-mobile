package com.example.zholdas.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val ZholdasBackground: Color @Composable get() = MaterialTheme.colorScheme.background
val ZholdasBackgroundDeep: Color @Composable get() = MaterialTheme.colorScheme.background
val ZholdasSurface: Color @Composable get() = MaterialTheme.colorScheme.surface
val ZholdasElevatedSurface: Color @Composable get() = MaterialTheme.colorScheme.surfaceContainerHigh
val ZholdasPanel: Color @Composable get() = MaterialTheme.colorScheme.surfaceContainer
val ZholdasBorder: Color @Composable get() = MaterialTheme.colorScheme.outlineVariant

val ZholdasAccent = Color(0xFF946BFE)
val ZholdasAccentDeep = Color(0xFF572EC7)
val ZholdasAccentSoft = Color(0xFF5C45C7)

val ZholdasSuccess = Color(0xFF2ECC80)
val ZholdasDanger = Color(0xFFFF4257)

val ZholdasTextPrimary: Color @Composable get() = MaterialTheme.colorScheme.onBackground
val ZholdasTextSecondary: Color @Composable get() = MaterialTheme.colorScheme.onSurfaceVariant
val ZholdasTextTertiary: Color @Composable get() = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)

// Backwards compatibility/Template colors
val Purple80 = Color(0xFFD0BCFF)
val PurpleGrey80 = Color(0xFFCCC2DC)
val Pink80 = Color(0xFFEFB8C8)

val Purple40 = Color(0xFF6650a4)
val PurpleGrey40 = Color(0xFF625b71)
val Pink40 = Color(0xFF7D5260)
