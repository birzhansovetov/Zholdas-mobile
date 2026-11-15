package com.example.zholdas.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class LegalLinksTest {

    private val testBaseUrl = "https://zholdas-api-de89a64e4196.herokuapp.com"

    @Test
    fun privacyUrl_buildsCorrectUrlForSupportedLanguages() {
        assertEquals("$testBaseUrl/privacy?lang=ru", LegalLinks.privacyUrl(testBaseUrl, "ru"))
        assertEquals("$testBaseUrl/privacy?lang=kk", LegalLinks.privacyUrl(testBaseUrl, "kk"))
        assertEquals("$testBaseUrl/privacy?lang=en", LegalLinks.privacyUrl(testBaseUrl, "en"))
    }

    @Test
    fun termsUrl_buildsCorrectUrlForSupportedLanguages() {
        assertEquals("$testBaseUrl/terms?lang=ru", LegalLinks.termsUrl(testBaseUrl, "ru"))
        assertEquals("$testBaseUrl/terms?lang=kk", LegalLinks.termsUrl(testBaseUrl, "kk"))
        assertEquals("$testBaseUrl/terms?lang=en", LegalLinks.termsUrl(testBaseUrl, "en"))
    }

    @Test
    fun legalLinks_trimsTrailingSlashAndAvoidsDoubleSlash() {
        val baseWithSlash = "$testBaseUrl/"
        val privacy = LegalLinks.privacyUrl(baseWithSlash, "ru")
        val terms = LegalLinks.termsUrl(baseWithSlash, "ru")

        assertEquals("$testBaseUrl/privacy?lang=ru", privacy)
        assertEquals("$testBaseUrl/terms?lang=ru", terms)
        assertFalse(privacy.contains("//privacy"))
        assertFalse(terms.contains("//terms"))

        val baseWithMultipleSlashes = "$testBaseUrl///"
        assertEquals("$testBaseUrl/privacy?lang=ru", LegalLinks.privacyUrl(baseWithMultipleSlashes, "ru"))
        assertEquals("$testBaseUrl/terms?lang=ru", LegalLinks.termsUrl(baseWithMultipleSlashes, "ru"))
    }

    @Test
    fun legalLinks_fallsBackToRuForUnsupportedOrInvalidLanguages() {
        assertEquals("$testBaseUrl/privacy?lang=ru", LegalLinks.privacyUrl(testBaseUrl, "fr"))
        assertEquals("$testBaseUrl/privacy?lang=ru", LegalLinks.privacyUrl(testBaseUrl, "es"))
        assertEquals("$testBaseUrl/privacy?lang=ru", LegalLinks.privacyUrl(testBaseUrl, ""))
        assertEquals("$testBaseUrl/privacy?lang=ru", LegalLinks.privacyUrl(testBaseUrl, "unknown"))

        assertEquals("$testBaseUrl/terms?lang=ru", LegalLinks.termsUrl(testBaseUrl, "de"))
        assertEquals("$testBaseUrl/terms?lang=ru", LegalLinks.termsUrl(testBaseUrl, ""))
    }

    @Test
    fun legalLinks_normalizesCaseAndWhitespace() {
        assertEquals("$testBaseUrl/privacy?lang=kk", LegalLinks.privacyUrl(testBaseUrl, " KK "))
        assertEquals("$testBaseUrl/terms?lang=en", LegalLinks.termsUrl(testBaseUrl, "EN"))
        assertEquals("$testBaseUrl/privacy?lang=ru", LegalLinks.privacyUrl("  $testBaseUrl/  ", "ru"))
    }
}
