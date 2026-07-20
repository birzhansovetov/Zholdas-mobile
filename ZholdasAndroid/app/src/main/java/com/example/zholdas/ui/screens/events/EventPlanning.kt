package com.example.zholdas.ui.screens.events

import com.example.zholdas.data.model.Event
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeParseException

enum class MyEventsFilter { CREATED, PARTICIPATING, PAST }

internal fun parseEventInstant(value: String): Instant? = try {
    Instant.parse(value)
} catch (_: DateTimeParseException) {
    try { OffsetDateTime.parse(value).toInstant() } catch (_: DateTimeParseException) { null }
}

fun filterMyEvents(events: List<Event>, currentUserID: String, filter: MyEventsFilter, now: Instant = Instant.now()): List<Event> {
    return events.filter { event ->
        val ended = parseEventInstant(event.endTime)?.isBefore(now) == true || event.status != "active"
        when (filter) {
            MyEventsFilter.CREATED -> !ended && event.creatorID == currentUserID
            MyEventsFilter.PARTICIPATING -> !ended && event.isJoined == true && event.creatorID != currentUserID
            MyEventsFilter.PAST -> ended && (event.creatorID == currentUserID || event.isJoined == true)
        }
    }.sortedBy { parseEventInstant(it.startTime) }
}

fun preparationCountdown(startTime: String, now: Instant = Instant.now()): String {
    val start = parseEventInstant(startTime) ?: return "Время начала не указано"
    val minutes = (start.epochSecond - now.epochSecond) / 60
    return when {
        minutes <= 0 -> "Событие уже началось"
        minutes < 60 -> "До начала $minutes мин"
        minutes < 1_440 -> "До начала ${minutes / 60} ч ${minutes % 60} мин"
        else -> "До начала ${minutes / 1_440} дн"
    }
}

fun eventLocalTime(startTime: String): String = parseEventInstant(startTime)
    ?.atZone(ZoneId.systemDefault())
    ?.toLocalDateTime()
    ?.toString()
    ?.replace('T', ' ')
    ?: startTime

fun applyParticipationResponse(events: List<Event>, eventId: Int, isJoined: Boolean, requestSucceeded: Boolean): List<Event> {
    if (!requestSucceeded) return events
    return events.map { event ->
    if (event.id != eventId) event else {
        val count = event.participantsCount ?: 0
        event.copy(
            isJoined = isJoined,
            participantsCount = if (isJoined) count + 1 else (count - 1).coerceAtLeast(0)
        )
    }
    }
}
