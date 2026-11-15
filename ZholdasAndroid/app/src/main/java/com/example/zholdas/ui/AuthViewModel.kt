package com.example.zholdas.ui

import android.content.ContentResolver
import android.net.Uri

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.zholdas.data.AppContainer
import com.example.zholdas.data.local.TokenManager
import com.example.zholdas.data.local.localized
import com.example.zholdas.data.model.DeviceTokenRequest
import com.example.zholdas.data.model.SignInRequest
import com.example.zholdas.data.model.*
import com.example.zholdas.data.remote.APIClient
import com.example.zholdas.data.remote.SupabaseSignUpPayload
import com.example.zholdas.data.remote.SupabaseUserData
import com.example.zholdas.data.remote.SupabaseVerifyPayload
import com.example.zholdas.data.remote.SupabaseResendPayload
import com.example.zholdas.data.remote.UpdatePasswordPayload
import com.example.zholdas.data.remote.toUserMessage
import com.example.zholdas.notifications.PushTokenProvider
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import retrofit2.HttpException
import java.io.IOException

private data class PendingRegistration(
    val email: String,
    val fullName: String,
    val bio: String?,
    val city: String?,
    val gender: String?,
    val birthYear: Int?,
    val photoData: ByteArray?,
    val avatarURL: String?
)

class AuthViewModel(
    val apiClient: APIClient,
    private val tokenManager: TokenManager,
    private val pushTokenProvider: PushTokenProvider
) : ViewModel() {

    companion object {
        private const val TAG = "AuthViewModel"
    }

    private val _isAuthenticated = MutableStateFlow(false)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated.asStateFlow()

    private val _isCheckingAuth = MutableStateFlow(true)
    val isCheckingAuth: StateFlow<Boolean> = _isCheckingAuth.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _currentUserProfile = MutableStateFlow<User?>(null)
    val currentUserProfile: StateFlow<User?> = _currentUserProfile.asStateFlow()

    private val _unreadNotificationsCount = MutableStateFlow(0)
    val unreadNotificationsCount: StateFlow<Int> = _unreadNotificationsCount.asStateFlow()

    private val _pendingVerificationEmail = MutableStateFlow<String?>(null)
    val pendingVerificationEmail: StateFlow<String?> = _pendingVerificationEmail.asStateFlow()

    private val _infoMessage = MutableStateFlow<String?>(null)
    val infoMessage: StateFlow<String?> = _infoMessage.asStateFlow()

    private var pendingRegistration: PendingRegistration? = null

    init {
        checkAuth()
        observeSessionExpiration()
    }

    private fun observeSessionExpiration() {
        viewModelScope.launch {
            tokenManager.sessionExpired.collect { expired ->
                if (expired) {
                    _currentUserProfile.value = null
                    _unreadNotificationsCount.value = 0
                    _isLoading.value = false
                    _isAuthenticated.value = false
                    _errorMessage.value = "session_expired".localized
                    pendingRegistration = null
                    _pendingVerificationEmail.value = null
                    _infoMessage.value = null
                    tokenManager.resetSessionExpired()
                }
            }
        }
    }

    fun checkAuth() {
        viewModelScope.launch {
            try {
                val tokens = tokenManager.restoreTokens()
                if (tokens != null) {
                    _isAuthenticated.value = true
                    fetchUserProfile()
                } else {
                    _isAuthenticated.value = false
                }
            } finally {
                _isCheckingAuth.value = false
            }
        }
    }

    fun signIn(email: String, password: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            _infoMessage.value = null
            val normalizedEmail = email.trim().lowercase()

            try {
                val response = apiClient.supabaseAuth.signIn(
                    SignInRequest(normalizedEmail, password)
                )
                tokenManager.saveTokens(response.accessToken, response.refreshToken)
                _isAuthenticated.value = true
                fetchUserProfile()
            } catch (e: HttpException) {
                val errorBody = try { e.response()?.errorBody()?.string() } catch (_: Exception) { null }
                if (AuthUseCases.isEmailNotConfirmedError(errorBody)) {
                    _pendingVerificationEmail.value = normalizedEmail
                    pendingRegistration = null
                    resendSignupCode()
                } else {
                    Log.e(TAG, "Sign in failed: ${e.message}", e)
                    _errorMessage.value = e.toUserMessage()
                }
            } catch (e: IOException) {
                Log.e(TAG, "Network error during sign in: ${e.message}", e)
                _errorMessage.value = "error_network".localized
            } catch (e: Exception) {
                if (e is CancellationException) throw e
                Log.e(TAG, "Sign in failed: ${e.message}", e)
                _errorMessage.value = e.toUserMessage()
            } finally {
                if (_pendingVerificationEmail.value == null) {
                    _isLoading.value = false
                }
            }
        }
    }

    fun signUp(
        email: String,
        password: String,
        username: String,
        fullName: String,
        avatarURL: String? = null,
        bio: String? = null,
        city: String? = null,
        photoData: ByteArray? = null,
        gender: String? = null,
        birthYear: Int? = null
    ) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            _infoMessage.value = null
            val normalizedEmail = email.trim().lowercase()

            try {
                val response = apiClient.supabaseAuth.signUp(
                    SupabaseSignUpPayload(
                        email = normalizedEmail,
                        password = password,
                        data = SupabaseUserData(username, fullName)
                    )
                )

                if (response.accessToken != null && response.refreshToken != null) {
                    tokenManager.saveTokens(response.accessToken, response.refreshToken)
                    _isAuthenticated.value = true
                    completeProfileSetup(
                        fullName = fullName,
                        bio = bio,
                        city = city,
                        gender = gender,
                        birthYear = birthYear,
                        photoData = photoData,
                        avatarURL = avatarURL
                    )
                } else {
                    pendingRegistration = PendingRegistration(
                        email = normalizedEmail,
                        fullName = fullName,
                        bio = bio,
                        city = city,
                        gender = gender,
                        birthYear = birthYear,
                        photoData = photoData,
                        avatarURL = avatarURL
                    )
                    _pendingVerificationEmail.value = normalizedEmail
                    _isLoading.value = false
                    return@launch
                }
            } catch (e: IOException) {
                Log.e(TAG, "Network error during sign up: ${e.message}", e)
                _errorMessage.value = "error_network".localized
            } catch (e: Exception) {
                if (e is CancellationException) throw e
                Log.e(TAG, "Sign up failed: ${e.message}", e)
                _errorMessage.value = e.toUserMessage()
            } finally {
                _isLoading.value = false
            }
        }
    }

    private suspend fun completeProfileSetup(
        fullName: String,
        bio: String?,
        city: String?,
        gender: String?,
        birthYear: Int?,
        photoData: ByteArray?,
        avatarURL: String?
    ) {
        var finalAvatarURL = avatarURL ?: ""

        if (photoData != null) {
            try {
                val requestBody = photoData.toRequestBody("image/jpeg".toMediaType())
                val part = MultipartBody.Part.createFormData("file", "avatar.jpg", requestBody)
                val uploadResponse = apiClient.apiService.uploadImage(part)
                finalAvatarURL = apiClient.backendBaseUrl + uploadResponse.url
            } catch (e: Exception) {
                if (e is CancellationException) throw e
                Log.e(TAG, "Failed to upload avatar: ${e.message}", e)
            }
        }

        if (finalAvatarURL.isNotEmpty() || !bio.isNullOrEmpty() || !city.isNullOrEmpty() || !gender.isNullOrEmpty() || birthYear != null) {
            try {
                val currentProfile = apiClient.apiService.getProfile()
                apiClient.apiService.updateProfile(
                    com.example.zholdas.data.model.UpdateProfileRequest(
                        fullName = fullName,
                        bio = if (!bio.isNullOrEmpty()) bio else currentProfile.bio,
                        city = if (!city.isNullOrEmpty()) city else currentProfile.city ?: "Алматы",
                        avatarURL = if (finalAvatarURL.isNotEmpty()) finalAvatarURL else currentProfile.avatarURL,
                        gender = gender ?: currentProfile.gender,
                        birthYear = birthYear ?: currentProfile.birthYear
                    )
                )
            } catch (e: Exception) {
                if (e is CancellationException) throw e
                Log.e(TAG, "Failed to update profile: ${e.message}", e)
            }
        }

        fetchUserProfile()
    }

    fun verifySignupCode(code: String) {
        val email = _pendingVerificationEmail.value ?: return
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            _infoMessage.value = null
            val cleanCode = AuthUseCases.cleanVerificationCode(code)

            try {
                val response = apiClient.supabaseAuth.verify(
                    SupabaseVerifyPayload(
                        type = "signup",
                        email = email,
                        token = cleanCode
                    )
                )
                tokenManager.saveTokens(response.accessToken, response.refreshToken)
                _isAuthenticated.value = true

                val pending = pendingRegistration
                if (pending != null) {
                    completeProfileSetup(
                        fullName = pending.fullName,
                        bio = pending.bio,
                        city = pending.city,
                        gender = pending.gender,
                        birthYear = pending.birthYear,
                        photoData = pending.photoData,
                        avatarURL = pending.avatarURL
                    )
                } else {
                    fetchUserProfile()
                }

                pendingRegistration = null
                _pendingVerificationEmail.value = null
            } catch (e: HttpException) {
                Log.e(TAG, "Verify signup code HTTP error: ${e.code()} - ${e.message}", e)
                if (e.code() in listOf(400, 401, 403, 422)) {
                    _errorMessage.value = "auth_code_invalid".localized
                } else {
                    _errorMessage.value = e.toUserMessage()
                }
            } catch (e: IOException) {
                Log.e(TAG, "Network error during code verification: ${e.message}", e)
                _errorMessage.value = "error_network".localized
            } catch (e: Exception) {
                if (e is CancellationException) throw e
                Log.e(TAG, "Verify signup code failed: ${e.message}", e)
                _errorMessage.value = e.toUserMessage()
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun resendSignupCode() {
        val email = _pendingVerificationEmail.value ?: return
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            _infoMessage.value = null
            try {
                apiClient.supabaseAuth.resend(
                    SupabaseResendPayload(
                        type = "signup",
                        email = email
                    )
                )
                _infoMessage.value = "auth_code_resent".localized
            } catch (e: HttpException) {
                Log.e(TAG, "Resend code HTTP error: ${e.code()} - ${e.message}", e)
                if (e.code() == 429) {
                    _errorMessage.value = "auth_code_resend_too_often".localized
                } else {
                    _errorMessage.value = e.toUserMessage()
                }
            } catch (e: IOException) {
                Log.e(TAG, "Network error during code resend: ${e.message}", e)
                _errorMessage.value = "error_network".localized
            } catch (e: Exception) {
                if (e is CancellationException) throw e
                Log.e(TAG, "Resend code failed: ${e.message}", e)
                _errorMessage.value = e.toUserMessage()
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun cancelPendingVerification() {
        pendingRegistration = null
        _pendingVerificationEmail.value = null
        _errorMessage.value = null
        _infoMessage.value = null
    }

    fun recoverPassword(email: String, onSuccess: () -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            try {
                apiClient.supabaseAuth.recover(com.example.zholdas.data.model.RecoverRequest(email.trim().lowercase()))
                onSuccess()
            } catch (e: Exception) {
                Log.e(TAG, "Password recovery failed: ${e.message}", e)
                _errorMessage.value = e.toUserMessage()
            } finally {
                _isLoading.value = false
            }
        }
    }

    suspend fun resetPassword(accessToken: String, newPassword: String): Boolean {
        _isLoading.value = true
        _errorMessage.value = null
        return try {
            apiClient.supabaseAuth.updatePassword(
                request = UpdatePasswordPayload(newPassword),
                authorization = "Bearer $accessToken"
            )
            tokenManager.clearTokens()
            _currentUserProfile.value = null
            _isAuthenticated.value = false
            true
        } catch (e: Exception) {
            Log.e(TAG, "Password reset failed: ${e.message}", e)
            _errorMessage.value = e.toUserMessage()
            false
        } finally {
            _isLoading.value = false
        }
    }

    fun signOut() {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                // Best-effort logout on the backend
                try {
                    apiClient.apiService.registerDeviceToken(DeviceTokenRequest(""))
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to clear device token on server: ${e.message}", e)
                }
                try {
                    apiClient.apiService.logout()
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to logout on server: ${e.message}", e)
                }
            } finally {
                tokenManager.clearTokens()
                _currentUserProfile.value = null
                _isAuthenticated.value = false
                _isLoading.value = false
                pendingRegistration = null
                _pendingVerificationEmail.value = null
                _infoMessage.value = null
            }
        }
    }

    fun deleteAccount(onResult: ((Boolean) -> Unit)? = null) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            try {
                apiClient.apiService.deleteAccount()
                tokenManager.clearTokens()
                _currentUserProfile.value = null
                _isAuthenticated.value = false
                pendingRegistration = null
                _pendingVerificationEmail.value = null
                _infoMessage.value = null
                onResult?.invoke(true)
            } catch (e: IOException) {
                Log.e(TAG, "Network error during deleteAccount: ${e.message}", e)
                _errorMessage.value = "error_network".localized
                onResult?.invoke(false)
            } catch (e: Exception) {
                if (e is CancellationException) throw e
                Log.e(TAG, "deleteAccount failed: ${e.message}", e)
                _errorMessage.value = "profile_delete_account_error".localized
                onResult?.invoke(false)
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun fetchUserProfile() {
        viewModelScope.launch {
            try {
                val profile = apiClient.apiService.getProfile()
                _currentUserProfile.value = profile
                fetchNotificationsCount()
                registerDeviceToken()
            } catch (e: HttpException) {
                Log.e(TAG, "Failed to fetch user profile: ${e.message}", e)
                if (e.code() == 401 && tokenManager.currentTokens() == null) {
                    _errorMessage.value = "session_expired".localized
                    _isAuthenticated.value = false
                    _currentUserProfile.value = null
                } else {
                    _errorMessage.value = "profile_load_retry_error".localized
                }
            } catch (e: IOException) {
                Log.e(TAG, "Network error while fetching user profile: ${e.message}", e)
                _errorMessage.value = "error_network".localized
            } catch (e: Exception) {
                Log.e(TAG, "Failed to fetch user profile: ${e.message}", e)
                _errorMessage.value = "profile_load_retry_error".localized
            }
        }
    }

    suspend fun updateUserProfile(
        fullName: String,
        bio: String,
        city: String,
        avatarURL: String
    ): Boolean {
        return try {
            apiClient.apiService.updateProfile(
                com.example.zholdas.data.model.UpdateProfileRequest(
                    fullName = fullName,
                    bio = bio,
                    city = city,
                    avatarURL = avatarURL
                )
            )
            val updatedProfile = apiClient.apiService.getProfile()
            _currentUserProfile.value = updatedProfile
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update profile: ${e.message}", e)
            _errorMessage.value = e.toUserMessage()
            false
        }
    }

    suspend fun uploadProfileImage(contentResolver: ContentResolver, uri: Uri): String? {
        return try {
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: error("Unable to read selected image")
            val mediaType = (contentResolver.getType(uri) ?: "image/jpeg").toMediaType()
            val extension = when (mediaType.subtype) {
                "png" -> "png"
                "webp" -> "webp"
                else -> "jpg"
            }
            val requestBody = bytes.toRequestBody(mediaType)
            val part = MultipartBody.Part.createFormData("file", "avatar.$extension", requestBody)
            val uploaded = apiClient.apiService.uploadImage(part).url
            if (uploaded.startsWith("http://") || uploaded.startsWith("https://")) uploaded
            else apiClient.backendBaseUrl.trimEnd('/') + "/" + uploaded.trimStart('/')
        } catch (e: Exception) {
            Log.e(TAG, "Failed to upload profile image: ${e.message}", e)
            _errorMessage.value = e.toUserMessage()
            null
        }
    }

    suspend fun fetchFriends(): List<User> {
        return try {
            apiClient.apiService.getFriends()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to fetch friends: ${e.message}", e)
            emptyList()
        }
    }

    suspend fun fetchFriendRequests(): List<User> {
        return try {
            apiClient.apiService.getFriendRequests()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to fetch friend requests: ${e.message}", e)
            emptyList()
        }
    }

    private fun fetchNotificationsCount() {
        viewModelScope.launch {
            try {
                val notifications = apiClient.apiService.getNotifications()
                _unreadNotificationsCount.value = notifications.count { !it.isRead }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to fetch notification count: ${e.message}")
            }
        }
    }

    private fun registerDeviceToken() {
        viewModelScope.launch {
            try {
                val token = pushTokenProvider.currentToken() ?: return@launch
                apiClient.apiService.registerDeviceToken(DeviceTokenRequest(token))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to register FCM device token: ${e.message}")
            }
        }
    }

    suspend fun fetchUserProfile(userId: String): User? {
        return try {
            apiClient.apiService.getUserProfileByID(userId)
        } catch (e: Exception) {
            Log.e(TAG, "fetchUserProfile failed: ${e.message}", e)
            null
        }
    }

    suspend fun fetchUserReviews(userId: String): List<UserReview> {
        return try {
            apiClient.apiService.getUserReviews(userId)
        } catch (e: Exception) {
            Log.e(TAG, "fetchUserReviews failed: ${e.message}", e)
            emptyList()
        }
    }

    suspend fun getFriendshipStatus(userId: String): String {
        return try {
            apiClient.apiService.getFriendshipStatus(userId).status
        } catch (e: Exception) {
            Log.e(TAG, "getFriendshipStatus failed: ${e.message}", e)
            "none"
        }
    }

    suspend fun sendFriendRequest(userId: String): Boolean {
        return try {
            apiClient.apiService.sendFriendRequest(userId)
            true
        } catch (e: Exception) {
            Log.e(TAG, "sendFriendRequest failed: ${e.message}", e)
            false
        }
    }

    suspend fun acceptFriendRequest(userId: String): Boolean {
        return try {
            apiClient.apiService.acceptFriendRequest(userId)
            true
        } catch (e: Exception) {
            Log.e(TAG, "acceptFriendRequest failed: ${e.message}", e)
            false
        }
    }

    suspend fun rejectFriendRequest(userId: String): Boolean {
        return try {
            apiClient.apiService.rejectFriendRequest(userId)
            true
        } catch (e: Exception) {
            Log.e(TAG, "rejectFriendRequest failed: ${e.message}", e)
            false
        }
    }

    suspend fun blockUser(userId: String): Boolean {
        return try {
            apiClient.apiService.blockUser(userId)
            true
        } catch (e: Exception) {
            Log.e(TAG, "blockUser failed: ${e.message}", e)
            false
        }
    }

    suspend fun unblockUser(userId: String): Boolean {
        return try {
            apiClient.apiService.unblockUser(userId)
            true
        } catch (e: Exception) {
            Log.e(TAG, "unblockUser failed: ${e.message}", e)
            false
        }
    }

    suspend fun rateParticipant(eventID: Int, rateeID: String, rating: Int, comment: String?): Boolean {
        return try {
            apiClient.apiService.rateParticipant(
                id = eventID,
                request = RateRequest(rateeID = rateeID, rating = rating, comment = comment)
            )
            true
        } catch (e: Exception) {
            Log.e(TAG, "rateParticipant failed: ${e.message}", e)
            false
        }
    }

    suspend fun fetchNotificationsList(): List<NotificationItem> {
        return try {
            apiClient.apiService.getNotifications()
        } catch (e: Exception) {
            Log.e(TAG, "fetchNotificationsList failed: ${e.message}", e)
            emptyList()
        }
    }

    suspend fun markAllNotificationsRead() {
        try {
            apiClient.apiService.markNotificationsRead()
            _unreadNotificationsCount.value = 0
        } catch (e: Exception) {
            Log.e(TAG, "markAllNotificationsRead failed: ${e.message}", e)
        }
    }

    fun clearError() {
        _errorMessage.value = null
    }

    fun clearInfoMessage() {
        _infoMessage.value = null
    }

    class Factory(private val container: AppContainer) : ViewModelProvider.Factory {
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            if (modelClass.isAssignableFrom(AuthViewModel::class.java)) {
                @Suppress("UNCHECKED_CAST")
                return AuthViewModel(container.apiClient, container.tokenManager, container.pushTokenProvider) as T
            }
            throw IllegalArgumentException("Unknown ViewModel class")
        }
    }
}
