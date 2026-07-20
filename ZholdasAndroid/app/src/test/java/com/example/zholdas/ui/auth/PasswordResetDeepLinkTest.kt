package com.example.zholdas.ui.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PasswordResetDeepLinkTest {
    @Test
    fun `parses recovery token from fragment`() {
        val result = PasswordResetDeepLink.parse(
            "zholdas://reset-password#access_token=abc.123&type=recovery&refresh_token=ignored"
        )
        assertEquals("abc.123", result?.accessToken)
        assertTrue(result?.isValid == true)
    }

    @Test
    fun `fragment parameters override query parameters like iOS`() {
        val result = PasswordResetDeepLink.parse(
            "zholdas://reset-password?access_token=query&type=recovery#access_token=fragment&type=recovery"
        )
        assertEquals("fragment", result?.accessToken)
    }

    @Test
    fun `decodes provider errors`() {
        val result = PasswordResetDeepLink.parse(
            "zholdas://reset-password#error_description=Link%20expired"
        )
        assertEquals("Link expired", result?.error)
        assertFalse(result?.isValid == true)
    }

    @Test
    fun `rejects unrelated links`() {
        assertNull(PasswordResetDeepLink.parse("zholdas://event/42"))
        assertNull(PasswordResetDeepLink.parse("https://example.com/reset-password"))
    }

    @Test
    fun `requires recovery type and token`() {
        assertFalse(PasswordResetDeepLink.parse("zholdas://reset-password#type=invite")!!.isValid)
        assertFalse(PasswordResetDeepLink.parse("zholdas://reset-password#type=recovery")!!.isValid)
    }
}
