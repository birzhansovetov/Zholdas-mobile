package com.example.zholdas.data.local

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.settingsDataStore by preferencesDataStore(name = "settings_prefs")

enum class AppTheme(val storageValue: String) {
    SYSTEM("system"),
    LIGHT("light"),
    DARK("dark");

    companion object {
        fun fromStorage(value: String?): AppTheme = entries.firstOrNull {
            it.storageValue == value
        } ?: SYSTEM
    }
}

class AppPreferences(private val context: Context) {
    companion object {
        private val LANGUAGE = stringPreferencesKey("language")
        private val THEME = stringPreferencesKey("theme")
        private val supportedLanguages = setOf("ru", "kk", "en")

        fun normalizeLanguage(value: String?): String =
            value?.takeIf { it in supportedLanguages } ?: "ru"
    }

    val language: Flow<String> = context.settingsDataStore.data.map { preferences ->
        normalizeLanguage(preferences[LANGUAGE])
    }

    val theme: Flow<AppTheme> = context.settingsDataStore.data.map { preferences ->
        AppTheme.fromStorage(preferences[THEME])
    }

    suspend fun setLanguage(language: String) {
        context.settingsDataStore.edit { it[LANGUAGE] = normalizeLanguage(language) }
    }

    suspend fun setTheme(theme: AppTheme) {
        context.settingsDataStore.edit { it[THEME] = theme.storageValue }
    }

}
