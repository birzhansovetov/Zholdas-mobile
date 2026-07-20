package com.example.zholdas.data.remote

import com.example.zholdas.BuildConfig
import com.example.zholdas.data.local.TokenManager
import com.example.zholdas.data.model.*
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Response
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.Call
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import retrofit2.http.*

// Supabase configuration matching iOS Config
object SupabaseConfig {
    const val PROJECT_URL = "https://wqjaolhmpxanjvadxngn.supabase.co"
    const val ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndxamFvbGhtcHhhbmp2YWR4bmduIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3Nzc5NDUsImV4cCI6MjA5NjM1Mzk0NX0.-7z5E9OTGsmBVXnK-veSovd-Vuza_HEglhTdNZ69alM"
}

// Supabase Auth Payload models
@Serializable
data class SupabaseSignUpPayload(
    val email: String,
    val password: String,
    val data: SupabaseUserData
)

@Serializable
data class SupabaseUserData(
    val username: String,
    @SerialName("full_name") val fullName: String
)

@Serializable
data class SupabaseSignUpResponse(
    @SerialName("access_token") val accessToken: String? = null,
    @SerialName("refresh_token") val refreshToken: String? = null
)

@Serializable
data class UploadResponse(
    val url: String
)

@Serializable
data class UpdatePasswordPayload(val password: String)

interface SupabaseAuthService {
    @POST("/auth/v1/token?grant_type=password")
    suspend fun signIn(
        @Body request: SignInRequest,
        @Header("apikey") apiKey: String = SupabaseConfig.ANON_KEY,
        @Header("Authorization") auth: String = "Bearer ${SupabaseConfig.ANON_KEY}"
    ): TokenResponse

    @POST("/auth/v1/signup")
    suspend fun signUp(
        @Body request: SupabaseSignUpPayload,
        @Header("apikey") apiKey: String = SupabaseConfig.ANON_KEY,
        @Header("Authorization") auth: String = "Bearer ${SupabaseConfig.ANON_KEY}"
    ): SupabaseSignUpResponse

    @POST("/auth/v1/token?grant_type=refresh_token")
    suspend fun refresh(
        @Body request: RefreshRequest,
        @Header("apikey") apiKey: String = SupabaseConfig.ANON_KEY,
        @Header("Authorization") auth: String = "Bearer ${SupabaseConfig.ANON_KEY}"
    ): TokenResponse

    @POST("/auth/v1/token?grant_type=refresh_token")
    fun refreshSync(
        @Body request: RefreshRequest,
        @Header("apikey") apiKey: String = SupabaseConfig.ANON_KEY,
        @Header("Authorization") auth: String = "Bearer ${SupabaseConfig.ANON_KEY}"
    ): Call<TokenResponse>

    @POST("/auth/v1/recover")
    suspend fun recover(
        @Body request: RecoverRequest,
        @Query("redirect_to") redirectTo: String = "zholdas://reset-password",
        @Header("apikey") apiKey: String = SupabaseConfig.ANON_KEY,
        @Header("Authorization") auth: String = "Bearer ${SupabaseConfig.ANON_KEY}"
    ): okhttp3.ResponseBody

    @PUT("/auth/v1/user")
    suspend fun updatePassword(
        @Body request: UpdatePasswordPayload,
        @Header("Authorization") authorization: String,
        @Header("apikey") apiKey: String = SupabaseConfig.ANON_KEY
    ): okhttp3.ResponseBody
}

interface ZholdasApiService {
    @POST("/auth/logout")
    suspend fun logout(): GenericMessageResponse

    @GET("/auth/me")
    suspend fun getProfile(): User

    @PUT("/auth/profile")
    suspend fun updateProfile(@Body request: UpdateProfileRequest): GenericMessageResponse

    @Multipart
    @POST("/upload")
    suspend fun uploadImage(@Part file: MultipartBody.Part): UploadResponse

    @POST("/auth/device-token")
    suspend fun registerDeviceToken(@Body request: DeviceTokenRequest): GenericMessageResponse

    @GET("/users/{id}")
    suspend fun getUserProfileByID(@Path("id") id: String): User

    @GET("/users/{id}/reviews")
    suspend fun getUserReviews(@Path("id") id: String): List<UserReview>

    @POST("/reports")
    suspend fun createReport(@Body request: ReportRequest): GenericMessageResponse

    @POST("/events")
    suspend fun createEvent(@Body request: CreateEventRequest): Event

    @PUT("/events/{id}")
    suspend fun updateEvent(@Path("id") id: Int, @Body request: CreateEventRequest): Event

    @GET("/events/nearby")
    suspend fun getNearbyEvents(
        @Query("latitude") latitude: Double,
        @Query("longitude") longitude: Double,
        @Query("radius_meters") radiusMeters: Double = 5000.0,
        @Query("limit") limit: Int = 20,
        @Query("offset") offset: Int = 0
    ): List<Event>

    @POST("/events/{id}/join")
    suspend fun joinEvent(@Path("id") id: Int): GenericMessageResponse

    @POST("/events/{id}/leave")
    suspend fun leaveEvent(@Path("id") id: Int): GenericMessageResponse

    @GET("/events/{id}/participants")
    suspend fun getEventParticipants(@Path("id") id: Int): List<Participant>

    @POST("/events/{id}/participant-status")
    suspend fun updateParticipantStatus(
        @Path("id") id: Int,
        @Body request: ParticipantStatusRequest
    ): ParticipantStatusResponse

    @POST("/events/{id}/arrive")
    suspend fun markArrived(@Path("id") id: Int, @Body request: LocationRequest): MarkArrivedResponse

    @POST("/events/{id}/live-location")
    suspend fun updateLiveLocation(@Path("id") id: Int, @Body request: LocationRequest): GenericMessageResponse

    @GET("/events/{id}/live-locations")
    suspend fun getLiveLocations(@Path("id") id: Int): List<EventLiveLocation>

    @DELETE("/events/{id}/live-location")
    suspend fun stopLiveLocation(@Path("id") id: Int): GenericMessageResponse

    @POST("/events/{id}/rate")
    suspend fun rateParticipant(
        @Path("id") id: Int,
        @Body request: RateRequest
    ): GenericMessageResponse

    @GET("/events/recommendations")
    suspend fun getAIRecommendations(
        @Query("q") query: String,
        @Query("latitude") latitude: Double,
        @Query("longitude") longitude: Double,
        @Query("radius_meters") radiusMeters: Double = 10000.0
    ): AIRecommendationResponse

    @POST("/ai/chat")
    suspend fun chatWithAI(@Body request: AIChatRequest): AIChatResponse

    @GET("/chats")
    suspend fun getChatSessions(): List<ChatSession>

    @GET("/events/{id}/messages")
    suspend fun getEventMessages(@Path("id") id: Int): List<EventMessageResponse>

    @POST("/events/{id}/messages")
    suspend fun sendEventMessage(
        @Path("id") id: Int,
        @Body request: SendMessageRequest
    ): EventMessageResponse

    @GET("/notifications")
    suspend fun getNotifications(): List<NotificationItem>

    @POST("/notifications/read")
    suspend fun markNotificationsRead(): GenericMessageResponse

    @POST("/friends/request/{id}")
    suspend fun sendFriendRequest(@Path("id") id: String): GenericMessageResponse

    @POST("/friends/accept/{id}")
    suspend fun acceptFriendRequest(@Path("id") id: String): GenericMessageResponse

    @POST("/friends/reject/{id}")
    suspend fun rejectFriendRequest(@Path("id") id: String): GenericMessageResponse

    @GET("/friends")
    suspend fun getFriends(): List<User>

    @GET("/friends/requests")
    suspend fun getFriendRequests(): List<User>

    @GET("/friends/status/{id}")
    suspend fun getFriendshipStatus(@Path("id") id: String): FriendshipStatusResponse

    @POST("/users/{id}/block")
    suspend fun blockUser(@Path("id") id: String): GenericMessageResponse

    @POST("/users/{id}/unblock")
    suspend fun unblockUser(@Path("id") id: String): GenericMessageResponse

    // Moderation routes
    @GET("/moderation/reports")
    suspend fun getReports(): List<Report>

    @POST("/moderation/users/{id}/ban")
    suspend fun banUser(
        @Path("id") id: String,
        @Body request: BanRequest = BanRequest(""),
        @Query("reason") reason: String = ""
    ): GenericMessageResponse

    @POST("/moderation/users/{id}/unban")
    suspend fun unbanUser(@Path("id") id: String): GenericMessageResponse

    @POST("/moderation/reports/{id}/close")
    suspend fun closeReport(@Path("id") id: Int): GenericMessageResponse

    @GET("/moderation/users")
    suspend fun getModerationUsers(): List<ModerationUser>

    @POST("/moderation/users/{id}/role")
    suspend fun updateUserRole(@Path("id") id: String, @Body request: RoleRequest): GenericMessageResponse

    @POST("/moderation/users/{id}/delete")
    suspend fun deleteUserPermanently(@Path("id") id: String): GenericMessageResponse

    @GET("/moderation/events")
    suspend fun getModerationEvents(): List<Event>

    @POST("/moderation/events/{id}/status")
    suspend fun updateEventStatus(@Path("id") id: Int, @Body request: StatusRequest): GenericMessageResponse

    @GET("/moderation/stats")
    suspend fun getModerationStats(): ModerationStats

    @GET("/moderation/audit-logs")
    suspend fun getModerationAuditLogs(): List<ModerationAuditLog>

    @GET("/moderation/settings")
    suspend fun getModerationSettings(): ModerationSettings

    @PUT("/moderation/settings")
    suspend fun updateModerationSettings(@Body request: ModerationSettings): ModerationSettings

    @POST("/moderation/broadcast")
    suspend fun broadcastNotification(@Body request: BroadcastRequest): GenericMessageResponse
}

class APIClient(
    private val tokenManager: TokenManager,
    val backendBaseUrl: String = BuildConfig.BACKEND_BASE_URL
) {
    private val refreshLock = Any()
    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        encodeDefaults = true
    }

    private val contentType = "application/json".toMediaType()

    // 1. Supabase Auth service
    val supabaseAuth: SupabaseAuthService by lazy {
        Retrofit.Builder()
            .baseUrl(SupabaseConfig.PROJECT_URL)
            .client(
                OkHttpClient.Builder()
                    .addInterceptor(HttpLoggingInterceptor().apply {
                        redactHeader("Authorization")
                        redactHeader("apikey")
                        level = if (BuildConfig.DEBUG) HttpLoggingInterceptor.Level.BASIC else HttpLoggingInterceptor.Level.NONE
                    })
                    .build()
            )
            .addConverterFactory(json.asConverterFactory(contentType))
            .build()
            .create(SupabaseAuthService::class.java)
    }

    // 2. Auth Interceptor for Go Backend requests
    private val authInterceptor = Interceptor { chain ->
        val accessToken = tokenManager.currentTokens()?.accessToken
        val requestBuilder = chain.request().newBuilder()
        if (accessToken != null) {
            requestBuilder.header("Authorization", "Bearer $accessToken")
        }
        chain.proceed(requestBuilder.build())
    }

    // 3. Authenticator for handling token expiration (401 Unauthorized)
    private val tokenAuthenticator = okhttp3.Authenticator { _, response ->
        if (response.code != 401 || responseCount(response) >= 2) return@Authenticator null

        synchronized(refreshLock) {
            val current = tokenManager.currentTokens() ?: return@synchronized null
            val requestToken = response.request.header("Authorization")
                ?.removePrefix("Bearer ")

            // Another request may already have refreshed while this response was in flight.
            if (!requestToken.isNullOrBlank() && requestToken != current.accessToken) {
                return@synchronized response.request.newBuilder()
                    .header("Authorization", "Bearer ${current.accessToken}")
                    .build()
            }

            try {
                val refreshResponse = supabaseAuth.refreshSync(RefreshRequest(current.refreshToken)).execute()
                val refreshed = refreshResponse.body()
                if (!refreshResponse.isSuccessful || refreshed == null) {
                    refreshResponse.errorBody()?.close()
                    tokenManager.clearTokensFromSyncContext()
                    return@synchronized null
                }
                tokenManager.saveTokensFromSyncContext(refreshed.accessToken, refreshed.refreshToken)
                response.request.newBuilder()
                    .header("Authorization", "Bearer ${refreshed.accessToken}")
                    .build()
            } catch (_: Exception) {
                tokenManager.clearTokensFromSyncContext()
                null
            }
        }
    }

    private fun responseCount(response: Response): Int {
        var count = 1
        var prior = response.priorResponse
        while (prior != null) {
            count++
            prior = prior.priorResponse
        }
        return count
    }

    // 4. Go Backend API service
    val apiService: ZholdasApiService by lazy {
        val okHttpClient = OkHttpClient.Builder()
            .addInterceptor(authInterceptor)
            .addInterceptor(HttpLoggingInterceptor().apply {
                redactHeader("Authorization")
                level = if (BuildConfig.DEBUG) HttpLoggingInterceptor.Level.BASIC else HttpLoggingInterceptor.Level.NONE
            })
            .authenticator(tokenAuthenticator)
            .build()

        Retrofit.Builder()
            .baseUrl(backendBaseUrl)
            .client(okHttpClient)
            .addConverterFactory(json.asConverterFactory(contentType))
            .build()
            .create(ZholdasApiService::class.java)
    }
}
