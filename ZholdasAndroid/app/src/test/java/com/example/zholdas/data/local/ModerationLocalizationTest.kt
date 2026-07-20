package com.example.zholdas.data.local

import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ModerationLocalizationTest {
    private val keys = listOf(
        "mod_audit_tab",
        "mod_audit_empty",
        "mod_audit_retry",
        "mod_audit_loading",
        "mod_audit_load_error",
        "mod_settings_load_error",
        "mod_settings_save_error",
        "mod_settings_admin_profile_error",
        "mod_settings_rate_error",
        "mod_settings_city_error"
    )

    @Test
    fun moderationKeysExistInAllSupportedLanguages() {
        val original = Localization.language
        try {
            listOf("ru", "kk", "en").forEach { language ->
                Localization.language = language
                keys.forEach { key ->
                    val value = Localization.get(key)
                    assertNotEquals("Missing $key for $language", key, value)
                    assertTrue("Blank $key for $language", value.isNotBlank())
                }
            }
        } finally {
            Localization.language = original
        }
    }
}
