package com.example.zholdas.ui.screens.events

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.ui.graphics.vector.ImageVector
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object EventUtils {
    fun formatEventDate(isoString: String): String {
        if (isoString.isBlank()) return "Скоро"
        return try {
            val parser = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
            val cleanStr = if (isoString.contains("Z")) {
                isoString.substringBefore("Z")
            } else {
                isoString
            }
            val date = parser.parse(cleanStr) ?: return isoString
            val formatter = SimpleDateFormat("d MMMM, HH:mm", Locale("ru"))
            formatter.format(date)
        } catch (e: Exception) {
            isoString
        }
    }

    fun formatEventDateFull(isoString: String): String {
        if (isoString.isBlank()) return "Скоро"
        return try {
            val parser = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
            val cleanStr = if (isoString.contains("Z")) {
                isoString.substringBefore("Z")
            } else {
                isoString
            }
            val date = parser.parse(cleanStr) ?: return isoString
            val dayFormatter = SimpleDateFormat("EEEE, d MMMM", Locale("ru"))
            val timeFormatter = SimpleDateFormat("HH:mm", Locale("ru"))
            "${dayFormatter.format(date).replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale("ru")) else it.toString() }}\n${timeFormatter.format(date)}"
        } catch (e: Exception) {
            isoString
        }
    }

    fun calculateDaysLeftText(isoString: String): String {
        if (isoString.isBlank()) return "Скоро"
        return try {
            val parser = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
            val cleanStr = if (isoString.contains("Z")) {
                isoString.substringBefore("Z")
            } else {
                isoString
            }
            val date = parser.parse(cleanStr) ?: return "Скоро"
            val diffMillis = date.time - System.currentTimeMillis()
            val diffDays = (diffMillis / (1000 * 60 * 60 * 24)).toInt()
            when {
                diffDays > 0 -> "Начнется через $diffDays д"
                diffDays == 0 -> "Начнется сегодня"
                else -> "Активность уже началась"
            }
        } catch (e: Exception) {
            "Скоро"
        }
    }

    fun getCategoryIcon(category: String): ImageVector {
        return when (category.lowercase(Locale.getDefault())) {
            "hiking" -> Icons.Default.Terrain
            "walk" -> Icons.Default.Park
            "sports" -> Icons.Default.SportsSoccer
            "board_games" -> Icons.Default.Casino
            "networking" -> Icons.Default.Coffee
            "theater" -> Icons.Default.TheaterComedy
            "restaurant" -> Icons.Default.Restaurant
            else -> Icons.Default.AutoAwesome
        }
    }

    fun getCategoryNameKey(category: String): String {
        return when (category.lowercase(Locale.getDefault())) {
            "hiking" -> "cat_mountains"
            "walk" -> "cat_walks"
            "sports" -> "cat_sports"
            "board_games" -> "cat_games"
            "networking" -> "cat_networking"
            "theater" -> "cat_theater"
            "restaurant" -> "cat_restaurant"
            else -> "cat_other"
        }
    }
}
