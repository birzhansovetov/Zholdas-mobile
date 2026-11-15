package com.example.zholdas.ui

import com.example.zholdas.ui.screens.events.EventWeatherSummary
import com.example.zholdas.ui.screens.events.checklistText
import com.example.zholdas.ui.screens.events.conditionKey
import com.example.zholdas.ui.screens.events.parseWeatherJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class EventWeatherTest {

    @Test
    fun parseWeatherJson_success() {
        val sampleJson = """
            {
              "latitude": 43.25,
              "longitude": 76.95,
              "generationtime_ms": 0.05,
              "utc_offset_seconds": 18000,
              "timezone": "Asia/Almaty",
              "timezone_abbreviation": "+05",
              "elevation": 810.0,
              "current_units": {
                "time": "iso8601",
                "interval": "seconds",
                "temperature_2m": "°C",
                "apparent_temperature": "°C",
                "precipitation": "mm",
                "weather_code": "wmo code",
                "wind_speed_10m": "km/h"
              },
              "current": {
                "time": "2026-11-16T01:45",
                "interval": 900,
                "temperature_2m": 18.5,
                "apparent_temperature": 17.2,
                "precipitation": 0.5,
                "weather_code": 61,
                "wind_speed_10m": 14.0
              }
            }
        """.trimIndent()

        val summary = parseWeatherJson(sampleJson)
        assertNotNull(summary)
        assertEquals(18.5, summary.temperature, 0.001)
        assertEquals(17.2, summary.apparentTemperature!!, 0.001)
        assertEquals(0.5, summary.precipitation!!, 0.001)
        assertEquals(61, summary.weatherCode)
        assertEquals(14.0, summary.windSpeed!!, 0.001)
    }

    @Test
    fun conditionKey_selectionByCode() {
        // Коды по заданию: (0, 2, 45, 61, 73, 95, 100)
        assertEquals("ev_weather_clear", conditionKey(0))
        assertEquals("ev_weather_cloudy", conditionKey(2))
        assertEquals("ev_weather_fog", conditionKey(45))
        assertEquals("ev_weather_rain", conditionKey(61))
        assertEquals("ev_weather_snow", conditionKey(73))
        assertEquals("ev_weather_thunderstorm", conditionKey(95))
        assertEquals("ev_weather_default", conditionKey(100))
    }

    @Test
    fun checklistText_formatsCorrectly() {
        val summary = EventWeatherSummary(
            temperature = 20.0,
            apparentTemperature = 18.0,
            precipitation = 1.2,
            weatherCode = 61,
            windSpeed = 15.0
        )
        val text = checklistText(summary)
        assertTrue(text.contains("18°C"))
        assertTrue(text.contains("1.2"))
        assertTrue(text.contains("15"))
    }
}
