package com.example.zholdas.ui.screens.events

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AcUnit
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.FilterDrama
import androidx.compose.material.icons.filled.Thunderstorm
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.ui.graphics.vector.ImageVector
import com.example.zholdas.data.local.localized
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.util.Locale
import kotlin.math.roundToInt

data class EventWeatherSummary(
    val temperature: Double,
    val apparentTemperature: Double? = null,
    val precipitation: Double? = null,
    val weatherCode: Int? = null,
    val windSpeed: Double? = null
) {
    val icon: ImageVector
        get() = weatherIcon(weatherCode)

    fun checklistText(): String = formatChecklistText(this)
}

@Serializable
data class OpenMeteoResponse(
    val current: OpenMeteoCurrent
)

@Serializable
data class OpenMeteoCurrent(
    @SerialName("temperature_2m") val temperature2m: Double,
    @SerialName("apparent_temperature") val apparentTemperature: Double? = null,
    val precipitation: Double? = null,
    @SerialName("weather_code") val weatherCode: Int? = null,
    @SerialName("wind_speed_10m") val windSpeed10m: Double? = null
)

val weatherJson = Json {
    ignoreUnknownKeys = true
    coerceInputValues = true
}

fun parseWeatherJson(jsonString: String): EventWeatherSummary {
    val decoded = weatherJson.decodeFromString<OpenMeteoResponse>(jsonString)
    val cur = decoded.current
    return EventWeatherSummary(
        temperature = cur.temperature2m,
        apparentTemperature = cur.apparentTemperature,
        precipitation = cur.precipitation,
        weatherCode = cur.weatherCode,
        windSpeed = cur.windSpeed10m
    )
}

fun conditionKey(code: Int?): String = when (code) {
    0 -> "ev_weather_clear"
    in 1..3 -> "ev_weather_cloudy"
    45, 48 -> "ev_weather_fog"
    in 51..67, in 80..82 -> "ev_weather_rain"
    in 71..77, in 85..86 -> "ev_weather_snow"
    in 95..99 -> "ev_weather_thunderstorm"
    else -> "ev_weather_default"
}

fun weatherIcon(code: Int?): ImageVector = when (code) {
    0 -> Icons.Filled.WbSunny
    in 1..3 -> Icons.Filled.Cloud
    45, 48 -> Icons.Filled.FilterDrama
    in 51..67, in 80..82 -> Icons.Filled.WaterDrop
    in 71..77, in 85..86 -> Icons.Filled.AcUnit
    in 95..99 -> Icons.Filled.Thunderstorm
    else -> Icons.Filled.Cloud
}

fun formatChecklistText(summary: EventWeatherSummary): String {
    val parts = mutableListOf<String>()
    summary.apparentTemperature?.let {
        parts.add("${"ev_weather_feels_like".localized} ${it.roundToInt()}°C")
    }
    if (summary.precipitation != null && summary.precipitation > 0.0) {
        val prec = String.format(Locale.US, "%.1f", summary.precipitation)
        parts.add("${"ev_weather_precipitation".localized} $prec ${"ev_weather_unit_mm".localized}")
    }
    summary.windSpeed?.let {
        parts.add("${"ev_weather_wind".localized} ${it.roundToInt()} ${"ev_weather_unit_kmh".localized}")
    }
    return parts.joinToString(", ")
}

fun checklistText(summary: EventWeatherSummary): String = formatChecklistText(summary)
