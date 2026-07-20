package com.example.zholdas.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.zholdas.theme.*

// Modern Card container matching Swift's .modernCard()
@Composable
fun ModernCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    val cardShape = RoundedCornerShape(20.dp)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .shadow(
                elevation = 8.dp,
                shape = cardShape,
                ambientColor = ZholdasBorder,
                spotColor = ZholdasBorder
            )
            .clip(cardShape)
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(
                        ZholdasElevatedSurface.copy(alpha = 0.96f),
                        ZholdasSurface.copy(alpha = 0.94f)
                    )
                )
            )
            .border(1.dp, ZholdasBorder, cardShape)
            .padding(18.dp),
        content = content
    )
}

// Input Field surface modifier matching Swift's .modernFieldSurface()
@Composable
fun Modifier.modernFieldSurface(isFocused: Boolean): Modifier = this
    .fillMaxWidth()
    .height(56.dp)
    .clip(RoundedCornerShape(12.dp))
    .background(if (isFocused) ZholdasElevatedSurface else ZholdasPanel)
    .border(
        width = 1.dp,
        color = if (isFocused) ZholdasAccent.copy(alpha = 0.72f) else ZholdasBorder,
        shape = RoundedCornerShape(12.dp)
    )
    .padding(horizontal = 16.dp)

// Primary Action Button surface matching Swift's .primaryActionSurface()
@Composable
fun PrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    isLoading: Boolean = false,
    enabled: Boolean = true
) {
    val buttonShape = RoundedCornerShape(16.dp)
    val alpha = if (enabled && !isLoading) 1f else 0.5f

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp)
            .shadow(
                elevation = if (enabled && !isLoading) 12.dp else 0.dp,
                shape = buttonShape,
                ambientColor = ZholdasAccent.copy(alpha = 0.22f),
                spotColor = ZholdasAccent.copy(alpha = 0.22f)
            )
            .clip(buttonShape)
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(ZholdasAccent, ZholdasAccentSoft, ZholdasAccentDeep)
                ),
                alpha = alpha
            )
            .clickable(enabled = enabled && !isLoading) { onClick() },
        contentAlignment = Alignment.Center
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                color = Color.White,
                modifier = Modifier.size(24.dp),
                strokeWidth = 2.dp
            )
        } else {
            Text(
                text = text,
                color = Color.White,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}
