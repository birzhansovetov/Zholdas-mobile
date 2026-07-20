package com.example.zholdas.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ChatAIUseCasesTest {

    @Test
    fun testParseAiCommand_withAiTag() {
        val parsed = ChatAIUseCases.parseAiCommand("Привет @ai посоветуй маршрут в горы")
        assertTrue(parsed.isAiCommand)
        assertEquals("@ai", parsed.mentionedTag)
        assertEquals("Привет  посоветуй маршрут в горы", parsed.cleanPrompt)
    }

    @Test
    fun testParseAiCommand_withZhorikTagCaseInsensitive() {
        val cyrillicParsed = ChatAIUseCases.parseAiCommand("@Жорик где побегать вечером?")
        assertTrue(cyrillicParsed.isAiCommand)
        assertEquals("где побегать вечером?", cyrillicParsed.cleanPrompt)

        val latinParsed = ChatAIUseCases.parseAiCommand("Подскажи антикафе @ZHORIK")
        assertTrue(latinParsed.isAiCommand)
        assertEquals("Подскажи антикафе", latinParsed.cleanPrompt)
    }

    @Test
    fun testParseAiCommand_emptyPromptAfterTagUsesFallback() {
        val parsed = ChatAIUseCases.parseAiCommand("   @ai   ")
        assertTrue(parsed.isAiCommand)
        assertEquals("Расскажи совет для нашей встречи в Алматы", parsed.cleanPrompt)
    }

    @Test
    fun testParseAiCommand_regularMessageWithoutTag() {
        val parsed = ChatAIUseCases.parseAiCommand("Всем привет! Кто возьмет термос?")
        assertFalse(parsed.isAiCommand)
        assertEquals("Всем привет! Кто возьмет термос?", parsed.cleanPrompt)
    }

    @Test
    fun testGenerateZhorikReply_weekendQuery() {
        val reply = ChatAIUseCases.generateZhorikReply("Куда сходить на выходных в Алматы?")
        assertTrue(reply.contains("Кок-Жайляу"))
        assertTrue(reply.contains("настольные игры"))
    }

    @Test
    fun testGenerateZhorikReply_sportsQuery() {
        val reply = ChatAIUseCases.generateZhorikReply("Хочу заняться спортом или бегом")
        assertTrue(reply.contains("Парке Первого Президента"))
        assertTrue(reply.contains("19:00"))
    }

    @Test
    fun testGenerateZhorikReply_boardGamesQuery() {
        val reply = ChatAIUseCases.generateZhorikReply("Где поиграть в настолки?")
        assertTrue(reply.contains("антикафе на Абая и Панфилова"))
    }

    @Test
    fun testGenerateZhorikReply_defaultResponse() {
        val reply = ChatAIUseCases.generateZhorikReply("Привет, расскажи о себе")
        assertTrue(reply.contains("Я Жорик, твой ИИ-помощник Жолдас"))
    }
}
