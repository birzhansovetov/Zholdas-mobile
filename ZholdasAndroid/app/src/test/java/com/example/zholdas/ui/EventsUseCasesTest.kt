package com.example.zholdas.ui

import com.example.zholdas.data.model.Event
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EventsUseCasesTest {

    private val sampleEvents = listOf(
        Event(
            id = 1,
            creatorID = "user_1",
            title = "Поход на Кок-Жайляу на рассвете",
            description = "Легкий треккинг в горах",
            category = "hiking",
            locationName = "Остановка Кок-Жайляу",
            latitude = 43.1872,
            longitude = 76.9531,
            maxParticipants = 15,
            participantsCount = 8,
            isJoined = false
        ),
        Event(
            id = 2,
            creatorID = "user_2",
            title = "Поход в Театр им. Лермонтова",
            description = "Спектакль Чайка",
            category = "theater",
            locationName = "Театр Лермонтова",
            latitude = 43.2425,
            longitude = 76.9458,
            maxParticipants = 10,
            participantsCount = 5,
            isJoined = false
        ),
        Event(
            id = 3,
            creatorID = "user_3",
            title = "Футбольный матч 6x6",
            description = "Играем в футбол в Парке Горького",
            category = "sports",
            locationName = "Парк Горького",
            latitude = 43.2567,
            longitude = 76.9754,
            maxParticipants = 12,
            participantsCount = 8,
            isJoined = false
        ),
        Event(
            id = 4,
            creatorID = "user_4",
            title = "Вечер настольных игр",
            description = "Играем в Каркассон и Бункер",
            category = "board_games",
            locationName = "Антикафе на Абая",
            latitude = 43.2411,
            longitude = 76.8912,
            maxParticipants = 8,
            participantsCount = 6,
            isJoined = true
        )
    )

    @Test
    fun testFilterEventsByCategory_all() {
        val filtered = EventsUseCases.filterEvents(sampleEvents, "cat_all", "")
        assertEquals(4, filtered.size)
    }

    @Test
    fun testFilterEventsByCategory_mountains() {
        val filtered = EventsUseCases.filterEvents(sampleEvents, "cat_mountains", "")
        assertEquals(1, filtered.size)
        assertEquals("Поход на Кок-Жайляу на рассвете", filtered.first().title)
    }

    @Test
    fun testFilterEventsByCategory_theater() {
        val filtered = EventsUseCases.filterEvents(sampleEvents, "cat_theater", "")
        assertEquals(1, filtered.size)
        assertEquals("Поход в Театр им. Лермонтова", filtered.first().title)
    }

    @Test
    fun testFilterEventsByCategory_sports() {
        val filtered = EventsUseCases.filterEvents(sampleEvents, "cat_sports", "")
        assertEquals(1, filtered.size)
        assertEquals("Футбольный матч 6x6", filtered.first().title)
    }

    @Test
    fun testFilterEventsByCategory_other() {
        val filtered = EventsUseCases.filterEvents(sampleEvents, "cat_other", "")
        assertEquals(1, filtered.size)
        assertEquals("Вечер настольных игр", filtered.first().title)
    }

    @Test
    fun testFilterEventsBySearchQuery_caseInsensitive() {
        val filtered = EventsUseCases.filterEvents(sampleEvents, "cat_all", "кок-жайляу")
        assertEquals(1, filtered.size)
        assertEquals("Поход на Кок-Жайляу на рассвете", filtered.first().title)
    }

    @Test
    fun testValidateCreateEvent_validInput() {
        val result = EventsUseCases.validateCreateEvent(
            title = "Кофе и IT-нетворкинг",
            locationName = "Кофейня Vanilla",
            maxParticipants = 10,
            startTime = "2026-07-10T10:00:00Z",
            endTime = "2026-07-10T12:00:00Z"
        )
        assertTrue(result.isValid)
    }

    @Test
    fun testValidateCreateEvent_emptyTitle() {
        val result = EventsUseCases.validateCreateEvent(
            title = "   ",
            locationName = "Кофейня Vanilla",
            maxParticipants = 10,
            startTime = "2026-07-10T10:00:00Z",
            endTime = "2026-07-10T12:00:00Z"
        )
        assertFalse(result.isValid)
        assertEquals("Название события не может быть пустым", result.errorMessage)
    }

    @Test
    fun testValidateCreateEvent_invalidParticipantsCount() {
        val result = EventsUseCases.validateCreateEvent(
            title = "Встреча",
            locationName = "Парк",
            maxParticipants = 0,
            startTime = "2026-07-10T10:00:00Z",
            endTime = "2026-07-10T12:00:00Z"
        )
        assertFalse(result.isValid)
        assertEquals("Количество участников должно быть больше 0", result.errorMessage)
    }

    @Test
    fun testApplyEventEdit() {
        val original = sampleEvents[0]
        val edited = EventsUseCases.applyEventEdit(
            original = original,
            title = "Обновленный поход на Кок-Жайляу",
            description = "Добавили точку сбора у эко-поста",
            category = "hiking",
            locationName = "Эко-пост Кок-Жайляу",
            latitude = 43.1890,
            longitude = 76.9540,
            maxParticipants = 20,
            genderFilter = "All",
            minAge = 18,
            maxAge = 45
        )

        assertEquals(1, edited.id)
        assertEquals("Обновленный поход на Кок-Жайляу", edited.title)
        assertEquals("Эко-пост Кок-Жайляу", edited.locationName)
        assertEquals(20, edited.maxParticipants)
        assertEquals(18, edited.minAge)
        assertEquals(45, edited.maxAge)
    }

    @Test
    fun testUpdateEventParticipation_joinAndLeave() {
        val original = sampleEvents[0] // participantsCount = 8, isJoined = false
        val joined = EventsUseCases.updateEventParticipation(original, isJoined = true)
        assertTrue(joined.isJoined == true)
        assertEquals(9, joined.participantsCount)

        val left = EventsUseCases.updateEventParticipation(joined, isJoined = false)
        assertFalse(left.isJoined == true)
        assertEquals(8, left.participantsCount)
    }
}
