package com.example.zholdas.data.remote

import com.example.zholdas.data.model.BroadcastRequest
import com.example.zholdas.data.model.GenericMessageResponse
import com.example.zholdas.data.model.LocationRequest
import com.example.zholdas.data.model.ModerationUser
import com.example.zholdas.data.model.ParticipantStatusResponse
import com.example.zholdas.data.model.User
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Pure JSON checks against the response/request fields emitted by the Go handlers. */
class BackendContractModelsTest {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    @Test
    fun moderationUser_decodesBackendUserIdAndRichFields() {
        val payload = """
            {
              "user_id":"6efba6ac-1ef5-42f8-b0d7-12f74472c13c",
              "username":"adina",
              "full_name":"Adina S.",
              "role":"moderator",
              "is_banned":true,
              "ban_reason":"spam",
              "gender":"female",
              "birth_year":2001,
              "age":25,
              "created_at":"2026-07-20T12:00:00Z",
              "email":"adina@example.com",
              "email_confirmed":true,
              "last_sign_in_at":null,
              "events_count":4,
              "reports_received":2,
              "reports_sent":1
            }
        """.trimIndent()

        val user = json.decodeFromString<ModerationUser>(payload)

        assertEquals("6efba6ac-1ef5-42f8-b0d7-12f74472c13c", user.id)
        assertEquals("moderator", user.role)
        assertTrue(user.isBanned)
        assertEquals(2001, user.birthYear)
        assertNull(user.lastSignInAt)
    }

    @Test
    fun profile_decodesDemographicFieldsReturnedByBackend() {
        val payload = """
            {
              "id":"user-id",
              "full_name":"User",
              "gender":"male",
              "birth_year":2000,
              "age":26,
              "email_confirmed":false
            }
        """.trimIndent()

        val user = json.decodeFromString<User>(payload)

        assertEquals("male", user.gender)
        assertEquals(2000, user.birthYear)
        assertEquals(26, user.age)
        assertFalse(user.emailConfirmed ?: true)
    }

    @Test
    fun createReport_decodesBackendMessageResponse() {
        val response = json.decodeFromString<GenericMessageResponse>(
            """{"message":"Report submitted successfully"}"""
        )

        assertEquals("Report submitted successfully", response.message)
    }

    @Test
    fun broadcastRequest_encodesTextFieldExpectedByBackend() {
        val payload = json.parseToJsonElement(
            json.encodeToString(BroadcastRequest(title = "Notice", message = "Hello"))
        ).jsonObject

        assertEquals("\"Notice\"", payload.getValue("title").toString())
        assertEquals("\"Hello\"", payload.getValue("text").toString())
        assertFalse(payload.containsKey("message"))
    }

    @Test
    fun eventLocationAndStatusContractsUseBackendFieldNames() {
        val location = json.parseToJsonElement(
            json.encodeToString(LocationRequest(43.2389, 76.8897, 8.5))
        ).jsonObject
        assertTrue(location.keys.containsAll(setOf("latitude", "longitude", "accuracy")))

        val status = json.decodeFromString<ParticipantStatusResponse>(
            """{"message":"Participant status updated","participant_status":"late","arrived_at":null}"""
        )
        assertEquals("late", status.participantStatus)
        assertNull(status.arrivedAt)
    }
}
