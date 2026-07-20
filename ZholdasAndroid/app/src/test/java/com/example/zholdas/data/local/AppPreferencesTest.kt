package com.example.zholdas.data.local

import org.junit.Assert.assertEquals
import org.junit.Test

class AppPreferencesTest {
    @Test
    fun `unknown and missing languages fall back to russian`() {
        assertEquals("ru", AppPreferences.normalizeLanguage(null))
        assertEquals("ru", AppPreferences.normalizeLanguage("de"))
    }

    @Test
    fun `supported languages are preserved`() {
        assertEquals("ru", AppPreferences.normalizeLanguage("ru"))
        assertEquals("kk", AppPreferences.normalizeLanguage("kk"))
        assertEquals("en", AppPreferences.normalizeLanguage("en"))
    }

    @Test
    fun `unknown and missing themes fall back to system`() {
        assertEquals(AppTheme.SYSTEM, AppTheme.fromStorage(null))
        assertEquals(AppTheme.SYSTEM, AppTheme.fromStorage("sepia"))
    }

    @Test
    fun `stored themes are restored`() {
        AppTheme.entries.forEach { theme ->
            assertEquals(theme, AppTheme.fromStorage(theme.storageValue))
        }
    }
}
