package com.example.zholdas.ui.screens.events

import com.example.zholdas.data.model.Event
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EventPlanningTest {
    private val now = Instant.parse("2026-07-12T10:00:00Z")

    private fun event(id: Int, creator: String, joined: Boolean, start: String, end: String, status: String = "active") = Event(
        id = id, creatorID = creator, isJoined = joined, startTime = start, endTime = end, status = status
    )

    @Test fun `created excludes past events`() {
        val events = listOf(
            event(1, "me", true, "2026-07-12T11:00:00Z", "2026-07-12T12:00:00Z"),
            event(2, "me", true, "2026-07-11T11:00:00Z", "2026-07-11T12:00:00Z")
        )
        assertEquals(listOf(1), filterMyEvents(events, "me", MyEventsFilter.CREATED, now).map { it.id })
    }

    @Test fun `participating excludes events created by current user`() {
        val events = listOf(
            event(1, "other", true, "2026-07-12T11:00:00Z", "2026-07-12T12:00:00Z"),
            event(2, "me", true, "2026-07-12T11:00:00Z", "2026-07-12T12:00:00Z")
        )
        assertEquals(listOf(1), filterMyEvents(events, "me", MyEventsFilter.PARTICIPATING, now).map { it.id })
    }

    @Test fun `past includes joined and created events`() {
        val events = listOf(
            event(1, "other", true, "2026-07-11T11:00:00Z", "2026-07-11T12:00:00Z"),
            event(2, "me", false, "2026-07-11T11:00:00Z", "2026-07-11T12:00:00Z"),
            event(3, "other", false, "2026-07-11T11:00:00Z", "2026-07-11T12:00:00Z")
        )
        assertEquals(setOf(1, 2), filterMyEvents(events, "me", MyEventsFilter.PAST, now).map { it.id }.toSet())
    }

    @Test fun `countdown formats hours and minutes`() {
        assertTrue(preparationCountdown("2026-07-12T12:30:00Z", now).contains("2 ч 30 мин"))
    }

    @Test fun `empty server list produces no my events`() {
        MyEventsFilter.entries.forEach { filter ->
            assertTrue(filterMyEvents(emptyList(), "me", filter, now).isEmpty())
        }
    }

    @Test fun `participation mutation only contains real server event`() {
        val source = listOf(event(10, "other", false, "2026-07-12T11:00:00Z", "2026-07-12T12:00:00Z").copy(participantsCount = 2))
        val joined = applyParticipationResponse(source, 10, true, requestSucceeded = true)
        assertEquals(1, joined.size)
        assertEquals(true, joined.single().isJoined)
        assertEquals(3, joined.single().participantsCount)
        assertEquals(source, applyParticipationResponse(source, 999, true, requestSucceeded = true))
    }

    @Test fun `failed participation request rolls back without fake success`() {
        val source = listOf(event(10, "other", false, "2026-07-12T11:00:00Z", "2026-07-12T12:00:00Z").copy(participantsCount = 2))
        assertEquals(source, applyParticipationResponse(source, 10, true, requestSucceeded = false))
    }
}
