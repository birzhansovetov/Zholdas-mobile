package com.example.zholdas.ui.screens.events

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class EventImageUploaderTest {
    @Test
    fun `relative upload path is resolved against backend`() {
        assertEquals(
            "https://api.zholdas.app/uploads/event.jpg",
            EventImageUploader.resolveUploadedUrl("https://api.zholdas.app/", "/uploads/event.jpg")
        )
    }

    @Test
    fun `absolute upload URL is preserved`() {
        assertEquals(
            "https://cdn.zholdas.app/event.webp",
            EventImageUploader.resolveUploadedUrl("https://api.zholdas.app", "https://cdn.zholdas.app/event.webp")
        )
    }

    @Test
    fun `supported mime types retain matching extension`() {
        assertEquals("png", EventImageUploader.extensionForMimeType("image/png"))
        assertEquals("webp", EventImageUploader.extensionForMimeType("image/webp"))
        assertEquals("heic", EventImageUploader.extensionForMimeType("image/heif"))
        assertEquals("jpg", EventImageUploader.extensionForMimeType("application/octet-stream"))
    }

    @Test
    fun `edit preserves existing URL without a new selection`() {
        assertEquals(
            "https://cdn/old.jpg",
            EventImageUploader.imageUrlForUpdate("https://cdn/old.jpg", null, selectedNewImage = false)
        )
    }

    @Test
    fun `edit uses uploaded URL for a new selection`() {
        assertEquals(
            "https://cdn/new.jpg",
            EventImageUploader.imageUrlForUpdate("https://cdn/old.jpg", "https://cdn/new.jpg", selectedNewImage = true)
        )
        assertNull(EventImageUploader.imageUrlForUpdate("https://cdn/old.jpg", null, selectedNewImage = true))
    }
}
