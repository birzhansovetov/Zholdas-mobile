package com.example.zholdas.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val ZholdasDarkColorScheme = darkColorScheme(
    primary = ZholdasAccent,
    onPrimary = Color.White,
    secondary = ZholdasAccentSoft,
    onSecondary = Color.White,
    tertiary = ZholdasAccentDeep,
    background = Color(0xFF060512),
    onBackground = Color.White,
    surface = Color(0xFF0F0C1F),
    onSurface = Color.White,
    error = ZholdasDanger,
    onError = Color.White
)

private val ZholdasLightColorScheme = lightColorScheme(
    primary = ZholdasAccentDeep,
    onPrimary = Color.White,
    secondary = ZholdasAccentSoft,
    onSecondary = Color.White,
    tertiary = ZholdasAccent,
    background = Color(0xFFF8F6FF),
    onBackground = Color(0xFF171321),
    surface = Color.White,
    onSurface = Color(0xFF171321),
    surfaceContainer = Color(0xFFF1EDFA),
    surfaceContainerHigh = Color(0xFFE9E2F6),
    onSurfaceVariant = Color(0xFF5E576A),
    outlineVariant = Color(0xFFD8D0E3),
    error = ZholdasDanger,
    onError = Color.White
)

@Composable
fun ZholdasTheme(
    darkTheme: Boolean = true,
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = if (darkTheme) ZholdasDarkColorScheme else ZholdasLightColorScheme,
        typography = Typography,
        content = content
    )
}
