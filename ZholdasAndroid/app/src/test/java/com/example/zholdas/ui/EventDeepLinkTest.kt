package com.example.zholdas.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class EventDeepLinkTest {
    @Test
    fun `parses zholdas event scheme`() {
        assertEquals(123, EventDeepLink.parse("zholdas://event/123"))
        assertEquals(42, EventDeepLink.parse("zholdas://event/42/"))
        assertEquals(999, EventDeepLink.parse("zholdas://events/999"))
        assertEquals(555, EventDeepLink.parse("zholdas:///event/555"))
    }

    @Test
    fun `parses backend base url event link`() {
        val result = EventDeepLink.parse("https://zholdas-api-de89a64e4196.herokuapp.com/events/123")
        assertEquals(123, result)

        val resultWithSlash = EventDeepLink.parse("https://zholdas-api-de89a64e4196.herokuapp.com/events/123/")
        assertEquals(123, resultWithSlash)

        val resultWithQuery = EventDeepLink.parse("https://zholdas-api-de89a64e4196.herokuapp.com/events/123?source=share")
        assertEquals(123, resultWithQuery)
    }

    @Test
    fun `parses custom backend base url`() {
        val customBase = "https://custom.backend.example.com"
        assertEquals(777, EventDeepLink.parse("https://custom.backend.example.com/events/777", customBase))
        assertNull(EventDeepLink.parse("https://other.backend.example.com/events/777", customBase))
    }

    @Test
    fun `returns null for invalid or non-numeric ids`() {
        assertNull(EventDeepLink.parse("zholdas://event/not-a-number"))
        assertNull(EventDeepLink.parse("zholdas://event/"))
        assertNull(EventDeepLink.parse("zholdas://event"))
        assertNull(EventDeepLink.parse("https://zholdas-api-de89a64e4196.herokuapp.com/events/abc"))
    }

    @Test
    fun `parses public app links with e and events paths`() {
        assertEquals(123, EventDeepLink.parse("https://www.zholdas.app/e/123"))
        assertEquals(456, EventDeepLink.parse("https://zholdas.app/e/456"))
        assertEquals(789, EventDeepLink.parse("http://www.zholdas.app/events/789"))
        assertEquals(101, EventDeepLink.parse("https://zholdas.app/events/101"))
        assertEquals(55, EventDeepLink.parse("https://www.zholdas.app/e/55/"))
        assertEquals(99, EventDeepLink.parse("https://www.zholdas.app/e/99?source=share"))
    }

    @Test
    fun `generates public event url`() {
        assertEquals("https://www.zholdas.app/e/123", EventDeepLink.eventUrl(123))
        assertEquals("https://www.zholdas.app/e/123", EventDeepLink.buildEventUrl(123))
    }

    @Test
    fun `returns null for unrelated schemes hosts or paths`() {
        assertNull(EventDeepLink.parse("zholdas://reset-password"))
        assertNull(EventDeepLink.parse("https://google.com/events/123"))
        assertNull(EventDeepLink.parse("https://zholdas-api-de89a64e4196.herokuapp.com/users/123"))
        assertNull(EventDeepLink.parse("https://www.zholdas.app/profile/123"))
        assertNull(EventDeepLink.parse("https://www.zholdas.app/e/not-a-number"))
        assertNull(EventDeepLink.parse("https://www.zholdas.app/e/"))
        assertNull(EventDeepLink.parse(null))
        assertNull(EventDeepLink.parse(""))
        assertNull(EventDeepLink.parse("   "))
    }
}
