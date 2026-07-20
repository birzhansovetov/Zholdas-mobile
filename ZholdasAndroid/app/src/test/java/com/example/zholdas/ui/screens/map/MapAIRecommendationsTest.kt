package com.example.zholdas.ui.screens.map

import com.example.zholdas.data.model.Event
import org.junit.Assert.assertEquals
import org.junit.Test

class MapAIRecommendationsTest {
    private fun event(id: Int) = Event(
        id = id, creatorID = "creator", title = "Event $id", description = "",
        category = "other", locationName = "Almaty", latitude = 43.2,
        longitude = 76.9, startTime = "", maxParticipants = 10
    )

    @Test fun `results follow AI ranking and ignore unknown ids`() {
        val result = MapViewModel.resolveRecommendations(listOf(event(1), event(2)), listOf(2, 99, 1))
        assertEquals(listOf(2, 1), result.map(Event::id))
    }

    @Test fun `duplicate recommendation ids are shown once`() {
        val result = MapViewModel.resolveRecommendations(listOf(event(1)), listOf(1, 1))
        assertEquals(listOf(1), result.map(Event::id))
    }
}
