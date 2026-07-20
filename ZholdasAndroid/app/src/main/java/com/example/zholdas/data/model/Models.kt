package com.example.zholdas.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// MARK: - Auth DTOs

@Serializable
data class SignUpRequest(
    val email: String,
    val password: String,
    val username: String,
    @SerialName("full_name") val fullName: String
)

@Serializable
data class SignUpResponse(
    @SerialName("user_id") val userID: String,
    val username: String,
    @SerialName("full_name") val fullName: String,
    val message: String
)

@Serializable
data class SignInRequest(
    val email: String,
    val password: String
)

@Serializable
data class RecoverRequest(
    val email: String
)

@Serializable
data class TokenResponse(
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String
)

@Serializable
data class RefreshRequest(
    @SerialName("refresh_token") val refreshToken: String
)

// MARK: - Domain Models

@Serializable
data class User(
    val id: String,
    val email: String = "",
    val username: String = "",
    @SerialName("full_name") val fullName: String = "",
    @SerialName("avatar_url") val avatarURL: String? = null,
    val bio: String? = null,
    val city: String? = null,
    @SerialName("events_count") val eventsCount: Int? = null,
    @SerialName("friends_count") val friendsCount: Int? = null,
    val rating: Double? = null,
    val role: String? = null,
    @SerialName("is_banned") val isBanned: Boolean? = null,
    val gender: String? = null,
    @SerialName("birth_year") val birthYear: Int? = null,
    val age: Int? = null,
    @SerialName("email_confirmed") val emailConfirmed: Boolean? = null
)

/**
 * The moderation endpoint intentionally exposes a richer user shape and names
 * its identifier `user_id` (profile endpoints use `id`). Keeping this DTO
 * separate prevents successful moderation responses from failing to decode.
 */
@Serializable
data class ModerationUser(
    @SerialName("user_id") val id: String,
    val email: String = "",
    val username: String = "",
    @SerialName("full_name") val fullName: String = "",
    @SerialName("avatar_url") val avatarURL: String? = null,
    val bio: String? = null,
    val city: String? = null,
    val gender: String? = null,
    @SerialName("birth_year") val birthYear: Int? = null,
    val age: Int? = null,
    val role: String = "user",
    @SerialName("is_banned") val isBanned: Boolean = false,
    @SerialName("ban_reason") val banReason: String = "",
    @SerialName("created_at") val createdAt: String = "",
    @SerialName("email_confirmed") val emailConfirmed: Boolean = false,
    @SerialName("last_sign_in_at") val lastSignInAt: String? = null,
    @SerialName("events_count") val eventsCount: Int = 0,
    @SerialName("reports_received") val reportsReceived: Int = 0,
    @SerialName("reports_sent") val reportsSent: Int = 0
)

@Serializable
data class UserReview(
    val id: Int,
    @SerialName("evaluator_name") val evaluatorName: String = "",
    @SerialName("reviewer_name") val reviewerNameField: String? = null,
    @SerialName("evaluator_avatar_url") val evaluatorAvatarURL: String? = null,
    val rating: Int = 5,
    val comment: String? = null,
    @SerialName("created_at") val createdAt: String = ""
) {
    val reviewerName: String
        get() = reviewerNameField ?: evaluatorName
}

@Serializable
data class Report(
    val id: Int,
    @SerialName("reporter_id") val reporterID: String = "",
    @SerialName("reporter_name") val reporterName: String = "",
    @SerialName("reported_user_id") val reportedUserID: String? = null,
    @SerialName("reported_user_name") val reportedUserName: String? = null,
    @SerialName("event_id") val eventID: Int? = null,
    @SerialName("event_title") val eventTitle: String? = null,
    @SerialName("message_id") val messageID: Int? = null,
    @SerialName("message_text") val messageText: String? = null,
    val reason: String = "",
    val description: String = "",
    @SerialName("created_at") val createdAt: String = ""
)

@Serializable
data class Event(
    val id: Int,
    @SerialName("creator_id") val creatorID: String = "",
    val title: String = "",
    val description: String = "",
    val category: String = "",
    @SerialName("location_name") val locationName: String = "",
    val latitude: Double = 0.0,
    val longitude: Double = 0.0,
    @SerialName("start_time") val startTime: String = "",
    @SerialName("end_time") val endTime: String = "",
    @SerialName("max_participants") val maxParticipants: Int = 0,
    val status: String = "active",
    @SerialName("image_url") val imageURL: String? = null,
    @SerialName("distance_meters") val distanceMeters: Double? = null,
    @SerialName("participants_count") val participantsCount: Int? = null,
    @SerialName("is_joined") val isJoined: Boolean? = null,
    val visibility: String? = null,
    @SerialName("gender_filter") val genderFilter: String? = null,
    @SerialName("min_age") val minAge: Int? = null,
    @SerialName("max_age") val maxAge: Int? = null,
    @SerialName("created_at") val createdAt: String? = null
)

@Serializable
data class Participant(
    val id: String,
    val username: String = "",
    @SerialName("full_name") val fullName: String = "",
    @SerialName("avatar_url") val avatarURL: String? = null,
    @SerialName("participant_status") val participantStatus: String = "going",
    @SerialName("arrived_at") val arrivedAt: String? = null
)

@Serializable
data class ParticipantStatusRequest(val status: String)

@Serializable
data class ParticipantStatusResponse(
    val message: String = "",
    @SerialName("participant_status") val participantStatus: String? = null,
    @SerialName("arrived_at") val arrivedAt: String? = null
)

@Serializable
data class LocationRequest(
    val latitude: Double,
    val longitude: Double,
    val accuracy: Double? = null
)

@Serializable
data class MarkArrivedResponse(
    val message: String = "",
    @SerialName("arrived_at") val arrivedAt: String? = null,
    @SerialName("distance_meters") val distanceMeters: Double? = null
)

@Serializable
data class EventLiveLocation(
    @SerialName("user_id") val userID: String,
    val username: String = "",
    @SerialName("full_name") val fullName: String = "",
    @SerialName("avatar_url") val avatarURL: String? = null,
    val latitude: Double,
    val longitude: Double,
    val accuracy: Double? = null,
    @SerialName("updated_at") val updatedAt: String = "",
    @SerialName("expires_at") val expiresAt: String = ""
)

@Serializable
data class ChatMessage(
    val id: String, // UUID
    @SerialName("sender_name") val senderName: String = "",
    @SerialName("sender_avatar_url") val senderAvatarURL: String? = null,
    val text: String = "",
    val timestamp: String = "",
    @SerialName("is_current_user") val isCurrentUser: Boolean = false,
    @SerialName("db_id") val dbID: Int? = null,
    @SerialName("sender_id") val senderID: String? = null
)

@Serializable
data class ChatSession(
    val id: Int,
    val title: String = "",
    val category: String = "",
    @SerialName("time_label") val timeLabel: String = "",
    @SerialName("last_message") val lastMessage: String = "",
    @SerialName("last_message_sender") val lastMessageSender: String = "",
    @SerialName("last_message_time") val lastMessageTime: String = "",
    @SerialName("is_completed") val isCompleted: Boolean = false,
    @SerialName("category_icon") val categoryIcon: String = "",
    @SerialName("category_color_hex") val categoryColorHex: String = "",
    val messages: List<ChatMessage> = emptyList()
)

@Serializable
data class NotificationItem(
    val id: Int,
    @SerialName("user_id") val userID: String = "",
    @SerialName("actor_id") val actorID: String? = null,
    @SerialName("actor_name") val actorName: String = "",
    @SerialName("actor_avatar_url") val actorAvatarURL: String? = null,
    @SerialName("event_id") val eventID: Int = 0,
    @SerialName("event_title") val eventTitle: String = "",
    @SerialName("notification_type") val notificationType: String = "", // "join", "leave", etc.
    val text: String = "",
    @SerialName("is_read") val isRead: Boolean = false,
    @SerialName("created_at") val createdAt: String = ""
)

@Serializable
data class CreateEventRequest(
    val title: String,
    val description: String,
    val category: String,
    @SerialName("location_name") val locationName: String,
    val latitude: Double,
    val longitude: Double,
    @SerialName("start_time") val startTime: String,
    @SerialName("end_time") val endTime: String,
    @SerialName("max_participants") val maxParticipants: Int,
    @SerialName("image_url") val imageURL: String? = null,
    val visibility: String? = null,
    @SerialName("gender_filter") val genderFilter: String? = null,
    @SerialName("min_age") val minAge: Int? = null,
    @SerialName("max_age") val maxAge: Int? = null
)

@Serializable
data class UpdateProfileRequest(
    @SerialName("full_name") val fullName: String,
    val bio: String? = null,
    val city: String? = null,
    @SerialName("avatar_url") val avatarURL: String? = null,
    val gender: String? = null,
    @SerialName("birth_year") val birthYear: Int? = null
)

@Serializable
data class DeviceTokenRequest(
    @SerialName("device_token") val deviceToken: String,
    val platform: String = "android"
)

@Serializable
data class RateRequest(
    @SerialName("ratee_id") val rateeID: String,
    val rating: Int,
    val comment: String? = null
)

@Serializable
data class ReportRequest(
    @SerialName("reported_user_id") val reportedUserID: String? = null,
    @SerialName("event_id") val eventID: Int? = null,
    @SerialName("message_id") val messageID: Int? = null,
    val reason: String,
    val description: String
)

@Serializable
data class RoleRequest(
    val role: String
)

@Serializable
data class StatusRequest(
    val status: String
)

@Serializable
data class BroadcastRequest(
    val title: String,
    @SerialName("text") val message: String
)

@Serializable
data class GenericMessageResponse(
    val message: String = ""
)

@Serializable
data class FriendshipStatusResponse(
    val status: String = "none" // "none", "pending_sent", "pending_received", "accepted"
)

@Serializable
data class EventMessageResponse(
    val id: Int,
    @SerialName("event_id") val eventID: Int = 0,
    @SerialName("sender_id") val senderID: String = "",
    @SerialName("sender_name") val senderName: String = "",
    @SerialName("sender_username") val senderUsername: String = "",
    @SerialName("sender_avatar_url") val senderAvatarURL: String? = null,
    val text: String = "",
    @SerialName("created_at") val createdAt: String = ""
)

@Serializable
data class SendMessageRequest(
    val text: String
)

@Serializable
data class AIRecommendationResponse(
    val answer: String = "",
    @SerialName("recommended_card_ids") val recommendedCardIDs: List<Int> = emptyList()
)

@Serializable
data class AIChatMessageItem(
    val role: String, // "user", "assistant"
    val text: String
)

@Serializable
data class AIChatRequest(
    val message: String,
    val history: List<AIChatMessageItem> = emptyList()
)

@Serializable
data class AIChatResponse(
    val reply: String = ""
)

@Serializable
data class BanRequest(
    val reason: String = ""
)

@Serializable
data class ModerationStats(
    val users: Int = 0,
    val events: Int = 0,
    @SerialName("active_events") val activeEvents: Int = 0,
    val messages: Int = 0,
    val reports: Int = 0,
    val bans: Int = 0,
    @SerialName("reg_today") val regToday: Int = 0,
    @SerialName("reg_7_days") val reg7Days: Int = 0,
    @SerialName("reg_30_days") val reg30Days: Int = 0,
    @SerialName("events_7_days") val events7Days: Int = 0,
    @SerialName("events_30_days") val events30Days: Int = 0,
    @SerialName("messages_7_days") val messages7Days: Int = 0,
    @SerialName("joins_7_days") val joins7Days: Int = 0,
    @SerialName("actives_7_days") val actives7Days: Int = 0,
    @SerialName("total_users") val totalUsers: Int = 0,
    @SerialName("total_events") val totalEvents: Int = 0,
    @SerialName("total_messages") val totalMessages: Int = 0,
    @SerialName("active_users_today") val activeUsersToday: Int = 0
)

@Serializable
data class ModerationAuditLog(
    val id: Int,
    @SerialName("moderator_id") val moderatorID: String,
    @SerialName("moderator_name") val moderatorName: String = "",
    @SerialName("action_type") val actionType: String,
    @SerialName("target_type") val targetType: String,
    @SerialName("target_id") val targetID: String,
    val details: String = "",
    @SerialName("created_at") val createdAt: String
)

@Serializable
data class ModerationSettings(
    @SerialName("ai_enabled") val aiEnabled: Boolean,
    @SerialName("ai_rate_limit_per_10m") val aiRateLimitPer10m: Int,
    @SerialName("default_city") val defaultCity: String
)
