package com.example.zholdas.ui

import com.example.zholdas.data.model.UserReview
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ProfileSocialUseCasesTest {

    @Test
    fun testUpdateProfileValidation_validInput() {
        val result = ProfileSocialUseCases.validateProfileUpdate(
            fullName = "Абылай Жолдас",
            city = "Алматы"
        )
        assertTrue(result.isValid)
    }

    @Test
    fun testUpdateProfileValidation_emptyFullName() {
        val result = ProfileSocialUseCases.validateProfileUpdate(
            fullName = "   ",
            city = "Алматы"
        )
        assertFalse(result.isValid)
        assertEquals("Имя пользователя не может быть пустым", result.errorMessage)
    }

    @Test
    fun testCityNormalization() {
        assertEquals("Алматы", ProfileSocialUseCases.normalizeCity(null))
        assertEquals("Алматы", ProfileSocialUseCases.normalizeCity("   "))
        assertEquals("Астана", ProfileSocialUseCases.normalizeCity(" Астана "))
    }

    @Test
    fun testSendFriendRequest_validUser() {
        val result = ProfileSocialUseCases.canSendFriendRequest(
            currentUserId = "user_1",
            targetUserId = "user_2",
            currentStatus = "none"
        )
        assertTrue(result.isValid)
    }

    @Test
    fun testSendFriendRequest_toSelf() {
        val result = ProfileSocialUseCases.canSendFriendRequest(
            currentUserId = "user_1",
            targetUserId = "user_1",
            currentStatus = "none"
        )
        assertFalse(result.isValid)
        assertEquals("Нельзя добавить самого себя в друзья", result.errorMessage)
    }

    @Test
    fun testSendFriendRequest_alreadyFriends() {
        val result = ProfileSocialUseCases.canSendFriendRequest(
            currentUserId = "user_1",
            targetUserId = "user_2",
            currentStatus = "friends"
        )
        assertFalse(result.isValid)
        assertEquals("Пользователь уже в друзьях", result.errorMessage)
    }

    @Test
    fun testSendFriendRequest_alreadyPending() {
        val result = ProfileSocialUseCases.canSendFriendRequest(
            currentUserId = "user_1",
            targetUserId = "user_2",
            currentStatus = "pending_sent"
        )
        assertFalse(result.isValid)
        assertEquals("Заявка в друзья уже отправлена", result.errorMessage)
    }

    @Test
    fun testFriendshipStatusTransitions() {
        assertEquals(
            "pending_sent",
            ProfileSocialUseCases.getNextFriendshipStatus(FriendshipAction.SEND, "none")
        )
        assertEquals(
            "friends",
            ProfileSocialUseCases.getNextFriendshipStatus(FriendshipAction.ACCEPT, "pending_received")
        )
        assertEquals(
            "none",
            ProfileSocialUseCases.getNextFriendshipStatus(FriendshipAction.REJECT, "pending_received")
        )
        assertEquals(
            "blocked",
            ProfileSocialUseCases.getNextFriendshipStatus(FriendshipAction.BLOCK, "friends")
        )
    }

    @Test
    fun testRateParticipant_validRating() {
        val result = ProfileSocialUseCases.validateRateParticipant(
            rating = 5,
            comment = "Отличный собеседник и любитель гор!"
        )
        assertTrue(result.isValid)
    }

    @Test
    fun testRateParticipant_invalidRatingValues() {
        val zeroRating = ProfileSocialUseCases.validateRateParticipant(0, "Плохо")
        assertFalse(zeroRating.isValid)
        assertEquals("Оценка должна быть от 1 до 5", zeroRating.errorMessage)

        val sixRating = ProfileSocialUseCases.validateRateParticipant(6, "Супер")
        assertFalse(sixRating.isValid)
        assertEquals("Оценка должна быть от 1 до 5", sixRating.errorMessage)
    }

    @Test
    fun testRateParticipant_commentTooLong() {
        val longComment = "a".repeat(501)
        val result = ProfileSocialUseCases.validateRateParticipant(4, longComment)
        assertFalse(result.isValid)
        assertEquals("Комментарий слишком длинный", result.errorMessage)
    }

    @Test
    fun testUserReviewReviewerNameFallback() {
        val reviewWithReviewerName = UserReview(
            id = 1,
            evaluatorName = "Ернар",
            reviewerNameField = "Айжан",
            rating = 5,
            comment = "Отличная встреча",
            createdAt = "2026-07-09"
        )
        assertEquals("Айжан", reviewWithReviewerName.reviewerName)

        val reviewWithoutReviewerName = UserReview(
            id = 2,
            evaluatorName = "Ернар",
            reviewerNameField = null,
            rating = 5,
            comment = "Супер",
            createdAt = "2026-07-09"
        )
        assertEquals("Ернар", reviewWithoutReviewerName.reviewerName)
    }
}
