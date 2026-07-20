package com.example.zholdas.ui

import com.example.zholdas.data.model.*
import com.example.zholdas.data.remote.*
import kotlinx.coroutines.test.runTest
import okhttp3.MultipartBody
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class ModeratorDashboardUseCasesTest {

    private lateinit var fakeApiService: FakeZholdasApiService
    private lateinit var useCases: ModeratorDashboardUseCases

    @Before
    fun setUp() {
        fakeApiService = FakeZholdasApiService()
        useCases = ModeratorDashboardUseCases(fakeApiService)
    }

    // 1. Role Checking Tests (admin / moderator)
    @Test
    fun isAdmin_returnsTrueForAdminRole() {
        val adminUser = User(id = "1", role = "admin")
        val adminUpperUser = User(id = "2", role = "ADMIN")

        assertTrue(useCases.isAdmin(adminUser))
        assertTrue(useCases.isAdmin(adminUpperUser))
    }

    @Test
    fun isAdmin_returnsFalseForModeratorOrUser() {
        val moderatorUser = User(id = "1", role = "moderator")
        val regularUser = User(id = "2", role = "user")
        val nullRoleUser = User(id = "3", role = null)

        assertFalse(useCases.isAdmin(moderatorUser))
        assertFalse(useCases.isAdmin(regularUser))
        assertFalse(useCases.isAdmin(nullRoleUser))
    }

    @Test
    fun isModeratorOrAdmin_returnsTrueForAdminAndModerator() {
        val adminUser = User(id = "1", role = "admin")
        val moderatorUser = User(id = "2", role = "moderator")

        assertTrue(useCases.isModeratorOrAdmin(adminUser))
        assertTrue(useCases.isModeratorOrAdmin(moderatorUser))
    }

    @Test
    fun isModeratorOrAdmin_returnsFalseForRegularUser() {
        val regularUser = User(id = "1", role = "user")
        assertFalse(useCases.isModeratorOrAdmin(regularUser))
    }

    @Test
    fun canBanUser_adminCanBanRegularUserOrModerator() {
        val admin = User(id = "admin_1", role = "admin")
        val user = User(id = "user_1", role = "user")
        val moderator = User(id = "mod_1", role = "moderator")

        assertTrue(useCases.canBanUser(admin, user))
        assertTrue(useCases.canBanUser(admin, moderator))
    }

    @Test
    fun canBanUser_moderatorCanBanRegularUserButNotAdminOrModerator() {
        val moderator = User(id = "mod_1", role = "moderator")
        val user = User(id = "user_1", role = "user")
        val admin = User(id = "admin_1", role = "admin")
        val otherMod = User(id = "mod_2", role = "moderator")

        assertTrue(useCases.canBanUser(moderator, user))
        assertFalse(useCases.canBanUser(moderator, admin))
        assertFalse(useCases.canBanUser(moderator, otherMod))
    }

    @Test
    fun canBanUser_cannotBanSelf() {
        val admin = User(id = "admin_1", role = "admin")
        assertFalse(useCases.canBanUser(admin, admin))
    }

    @Test
    fun canUpdateUserRole_onlyAdminCanUpdateRoleOfAnotherUser() {
        val admin = User(id = "admin_1", role = "admin")
        val moderator = User(id = "mod_1", role = "moderator")
        val user = User(id = "user_1", role = "user")

        assertTrue(useCases.canUpdateUserRole(admin, user))
        assertFalse(useCases.canUpdateUserRole(admin, admin))
        assertFalse(useCases.canUpdateUserRole(moderator, user))
        assertFalse(useCases.canUpdateUserRole(user, moderator))
    }

    // 2. Logic of Blocking Users (BanRequest)
    @Test
    fun banUser_validInput_callsApiServiceWithBanRequest() = runTest {
        val response = useCases.banUser(userId = "user_123", reason = "Spamming in chats")

        assertEquals("user_banned", response.message)
        assertEquals("user_123", fakeApiService.lastBannedUserId)
        assertEquals("Spamming in chats", fakeApiService.lastBanRequest?.reason)
        assertEquals("Spamming in chats", fakeApiService.lastBanReasonQuery)
    }

    @Test(expected = IllegalArgumentException::class)
    fun banUser_emptyUserId_throwsIllegalArgumentException() = runTest {
        useCases.banUser(userId = "", reason = "Spam")
    }

    @Test(expected = IllegalArgumentException::class)
    fun banUser_emptyReason_throwsIllegalArgumentException() = runTest {
        useCases.banUser(userId = "user_123", reason = "   ")
    }

    @Test
    fun unbanUser_validInput_callsApiServiceUnban() = runTest {
        val response = useCases.unbanUser("user_123")

        assertEquals("user_unbanned", response.message)
        assertEquals("user_123", fakeApiService.lastUnbannedUserId)
    }

    // 3. Statistics (ModerationStats)
    @Test
    fun getModerationStats_returnsStatsFromService() = runTest {
        val expectedStats = ModerationStats(
            users = 150,
            events = 45,
            activeEvents = 30,
            reports = 5,
            bans = 2,
            totalUsers = 150,
            totalEvents = 45
        )
        fakeApiService.statsToReturn = expectedStats

        val stats = useCases.getModerationStats()

        assertEquals(150, stats.users)
        assertEquals(45, stats.events)
        assertEquals(30, stats.activeEvents)
        assertEquals(5, stats.reports)
        assertEquals(2, stats.bans)
    }

    @Test
    fun calculateActiveEventsRatio_computesCorrectRatio() {
        val stats = ModerationStats(activeEvents = 30, totalEvents = 60)
        val ratio = useCases.calculateActiveEventsRatio(stats)

        assertEquals(50.0f, ratio, 0.001f)
    }

    @Test
    fun calculateActiveEventsRatio_usesCurrentBackendEventsField() {
        val stats = ModerationStats(events = 80, activeEvents = 20)

        assertEquals(25.0f, useCases.calculateActiveEventsRatio(stats), 0.001f)
    }

    @Test
    fun calculateActiveEventsRatio_returnsZeroWhenTotalEventsZero() {
        val stats = ModerationStats(activeEvents = 0, totalEvents = 0)
        val ratio = useCases.calculateActiveEventsRatio(stats)

        assertEquals(0.0f, ratio, 0.001f)
    }

    // 4. Changing Event Statuses (StatusRequest)
    @Test
    fun updateEventStatus_validStatus_callsApiServiceWithStatusRequest() = runTest {
        val response = useCases.updateEventStatus(eventId = 101, newStatus = "closed")

        assertEquals("event_status_updated", response.message)
        assertEquals(101, fakeApiService.lastUpdatedEventId)
        assertEquals("closed", fakeApiService.lastStatusRequest?.status)
    }

    @Test
    fun updateEventStatus_caseInsensitive_convertsToLowercase() = runTest {
        useCases.updateEventStatus(eventId = 102, newStatus = "ACTIVE")

        assertEquals(102, fakeApiService.lastUpdatedEventId)
        assertEquals("active", fakeApiService.lastStatusRequest?.status)
    }

    @Test
    fun updateEventStatus_deleted_matchesBackendContract() = runTest {
        useCases.updateEventStatus(eventId = 103, newStatus = "deleted")

        assertEquals("deleted", fakeApiService.lastStatusRequest?.status)
    }

    @Test(expected = IllegalArgumentException::class)
    fun updateEventStatus_blocked_isNotAcceptedByModerationEndpoint() = runTest {
        useCases.updateEventStatus(eventId = 103, newStatus = "blocked")
    }

    @Test(expected = IllegalArgumentException::class)
    fun updateEventStatus_invalidStatus_throwsIllegalArgumentException() = runTest {
        useCases.updateEventStatus(eventId = 101, newStatus = "unknown_status")
    }

    @Test(expected = IllegalArgumentException::class)
    fun updateEventStatus_invalidEventId_throwsIllegalArgumentException() = runTest {
        useCases.updateEventStatus(eventId = 0, newStatus = "active")
    }

    // 5. Updating User Role (RoleRequest)
    @Test
    fun updateUserRole_validRole_callsApiServiceWithRoleRequest() = runTest {
        val response = useCases.updateUserRole(userId = "user_55", newRole = "moderator")

        assertEquals("role_updated", response.message)
        assertEquals("user_55", fakeApiService.lastRoleUpdatedUserId)
        assertEquals("moderator", fakeApiService.lastRoleRequest?.role)
    }

    @Test(expected = IllegalArgumentException::class)
    fun updateUserRole_invalidRole_throwsIllegalArgumentException() = runTest {
        useCases.updateUserRole(userId = "user_55", newRole = "superadmin")
    }

    @Test fun validateSettings_acceptsBackendRange() {
        val result = useCases.validateSettings("8", "Almaty")
        assertTrue(result.isValid)
        assertEquals(8, result.rateLimit)
    }

    @Test fun validateSettings_rejectsOutOfRangeAndBlankCity() {
        assertFalse(useCases.validateSettings("101", "Almaty").isValid)
        assertFalse(useCases.validateSettings("8", " ").isValid)
    }

    @Test(expected = IllegalArgumentException::class)
    fun loadSettings_rejectsModeratorLocally() = runTest {
        useCases.loadSettings(User("mod", role = "moderator"))
    }

    @Test fun saveSettings_sendsNormalizedSupportedFields() = runTest {
        val saved = useCases.saveSettings(User("admin", role = "admin"), false, "12", "  Astana  ")
        assertFalse(saved.aiEnabled)
        assertEquals(12, saved.aiRateLimitPer10m)
        assertEquals("Astana", saved.defaultCity)
    }
}

private class FakeZholdasApiService : ZholdasApiService {
    var lastBannedUserId: String? = null
    var lastBanRequest: BanRequest? = null
    var lastBanReasonQuery: String? = null
    var lastUnbannedUserId: String? = null
    var lastUpdatedEventId: Int? = null
    var lastStatusRequest: StatusRequest? = null
    var lastRoleUpdatedUserId: String? = null
    var lastRoleRequest: RoleRequest? = null

    var statsToReturn = ModerationStats()

    override suspend fun banUser(id: String, request: BanRequest, reason: String): GenericMessageResponse {
        lastBannedUserId = id
        lastBanRequest = request
        lastBanReasonQuery = reason
        return GenericMessageResponse("user_banned")
    }

    override suspend fun unbanUser(id: String): GenericMessageResponse {
        lastUnbannedUserId = id
        return GenericMessageResponse("user_unbanned")
    }

    override suspend fun updateEventStatus(id: Int, request: StatusRequest): GenericMessageResponse {
        lastUpdatedEventId = id
        lastStatusRequest = request
        return GenericMessageResponse("event_status_updated")
    }

    override suspend fun updateUserRole(id: String, request: RoleRequest): GenericMessageResponse {
        lastRoleUpdatedUserId = id
        lastRoleRequest = request
        return GenericMessageResponse("role_updated")
    }

    override suspend fun getModerationStats(): ModerationStats {
        return statsToReturn
    }

    override suspend fun closeReport(id: Int): GenericMessageResponse {
        return GenericMessageResponse("report_closed")
    }

    // Other ZholdasApiService methods
    override suspend fun logout(): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun getProfile(): User = User("1")
    override suspend fun updateProfile(request: UpdateProfileRequest): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun uploadImage(file: MultipartBody.Part): UploadResponse = UploadResponse("url")
    override suspend fun registerDeviceToken(request: DeviceTokenRequest): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun getUserProfileByID(id: String): User = User(id)
    override suspend fun getUserReviews(id: String): List<UserReview> = emptyList()
    override suspend fun createReport(request: ReportRequest): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun createEvent(request: CreateEventRequest): Event = Event(1)
    override suspend fun updateEvent(id: Int, request: CreateEventRequest): Event = Event(id)
    override suspend fun getNearbyEvents(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        limit: Int,
        offset: Int
    ): List<Event> = emptyList()
    override suspend fun joinEvent(id: Int): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun leaveEvent(id: Int): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun getEventParticipants(id: Int): List<Participant> = emptyList()
    override suspend fun updateParticipantStatus(
        id: Int,
        request: ParticipantStatusRequest
    ): ParticipantStatusResponse = ParticipantStatusResponse(participantStatus = request.status)
    override suspend fun markArrived(
        id: Int,
        request: LocationRequest
    ): MarkArrivedResponse = MarkArrivedResponse(message = "ok")
    override suspend fun updateLiveLocation(
        id: Int,
        request: LocationRequest
    ): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun getLiveLocations(id: Int): List<EventLiveLocation> = emptyList()
    override suspend fun stopLiveLocation(id: Int): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun rateParticipant(id: Int, request: RateRequest): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun getAIRecommendations(
        query: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double
    ): AIRecommendationResponse = AIRecommendationResponse()
    override suspend fun chatWithAI(request: AIChatRequest): AIChatResponse = AIChatResponse()
    override suspend fun getChatSessions(): List<ChatSession> = emptyList()
    override suspend fun getEventMessages(id: Int): List<EventMessageResponse> = emptyList()
    override suspend fun sendEventMessage(id: Int, request: SendMessageRequest): EventMessageResponse = EventMessageResponse(1)
    override suspend fun getNotifications(): List<NotificationItem> = emptyList()
    override suspend fun markNotificationsRead(): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun sendFriendRequest(id: String): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun acceptFriendRequest(id: String): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun rejectFriendRequest(id: String): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun getFriends(): List<User> = emptyList()
    override suspend fun getFriendRequests(): List<User> = emptyList()
    override suspend fun getFriendshipStatus(id: String): FriendshipStatusResponse = FriendshipStatusResponse()
    override suspend fun blockUser(id: String): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun unblockUser(id: String): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun getReports(): List<Report> = emptyList()
    override suspend fun getModerationUsers(): List<ModerationUser> = emptyList()
    override suspend fun deleteUserPermanently(id: String): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun getModerationEvents(): List<Event> = emptyList()
    override suspend fun broadcastNotification(request: BroadcastRequest): GenericMessageResponse = GenericMessageResponse("ok")
    override suspend fun getModerationAuditLogs(): List<ModerationAuditLog> = emptyList()
    override suspend fun getModerationSettings(): ModerationSettings = ModerationSettings(true, 8, "Almaty")
    override suspend fun updateModerationSettings(request: ModerationSettings): ModerationSettings = request
}
