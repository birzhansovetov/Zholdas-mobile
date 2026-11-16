package com.example.zholdas.ui.screens.events

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.ui.graphics.vector.ImageVector
import com.example.zholdas.data.local.localized
import com.example.zholdas.data.model.Event
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object EventUtils {
    fun formatEventDate(isoString: String): String {
        if (isoString.isBlank()) return "common_soon".localized
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
        if (isoString.isBlank()) return "common_soon".localized
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
        if (isoString.isBlank()) return "common_soon".localized
        return try {
            val parser = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
            val cleanStr = if (isoString.contains("Z")) {
                isoString.substringBefore("Z")
            } else {
                isoString
            }
            val date = parser.parse(cleanStr) ?: return "common_soon".localized
            val diffMillis = date.time - System.currentTimeMillis()
            val diffDays = (diffMillis / (1000 * 60 * 60 * 24)).toInt()
            when {
                diffDays > 0 -> String.format("ev_starts_in_days_format".localized, diffDays)
                diffDays == 0 -> "ev_starts_today".localized
                else -> "ev_already_started".localized
            }
        } catch (e: Exception) {
            "common_soon".localized
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

    fun formatRestrictions(
        genderFilter: String?,
        minAge: Int?,
        maxAge: Int?,
        prefix: String,
        menOnly: String,
        womenOnly: String,
        ageRangeFormat: String,
        ageFromFormat: String,
        ageToFormat: String
    ): String? {
        val normalizedGender = genderFilter?.trim()?.lowercase(Locale.ROOT)
        val genderPart = when (normalizedGender) {
            "male" -> menOnly
            "female" -> womenOnly
            else -> null
        }

        val validMin = minAge?.takeIf { it > 0 }
        val validMax = maxAge?.takeIf { it > 0 }

        val agePart = when {
            validMin != null && validMax != null -> String.format(Locale.ROOT, ageRangeFormat, validMin, validMax)
            validMin != null -> String.format(Locale.ROOT, ageFromFormat, validMin)
            validMax != null -> String.format(Locale.ROOT, ageToFormat, validMax)
            else -> null
        }

        val parts = listOfNotNull(genderPart, agePart)
        if (parts.isEmpty()) {
            return null
        }

        return prefix + parts.joinToString(" · ")
    }

    fun formatRestrictions(
        genderFilter: String?,
        minAge: Int?,
        maxAge: Int?
    ): String? {
        return formatRestrictions(
            genderFilter = genderFilter,
            minAge = minAge,
            maxAge = maxAge,
            prefix = "ev_restr_prefix".localized,
            menOnly = "ev_restr_men".localized,
            womenOnly = "ev_restr_women".localized,
            ageRangeFormat = "ev_restr_age_range".localized,
            ageFromFormat = "ev_restr_age_from".localized,
            ageToFormat = "ev_restr_age_to".localized
        )
    }

    fun formatRestrictions(event: Event): String? {
        return formatRestrictions(
            genderFilter = event.genderFilter,
            minAge = event.minAge,
            maxAge = event.maxAge
        )
    }
}
