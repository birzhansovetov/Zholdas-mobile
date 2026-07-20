package com.example.zholdas.ui

import android.content.ContentResolver
import android.net.Uri

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.zholdas.data.AppContainer
import com.example.zholdas.data.local.TokenManager
import com.example.zholdas.data.model.DeviceTokenRequest
import com.example.zholdas.data.model.SignInRequest
import com.example.zholdas.data.model.*
import com.example.zholdas.data.remote.APIClient
import com.example.zholdas.data.remote.SupabaseSignUpPayload
import com.example.zholdas.data.remote.SupabaseUserData
import com.example.zholdas.data.remote.UpdatePasswordPayload
import com.example.zholdas.notifications.PushTokenProvider
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

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

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _currentUserProfile = MutableStateFlow<User?>(null)
    val currentUserProfile: StateFlow<User?> = _currentUserProfile.asStateFlow()

    private val _unreadNotificationsCount = MutableStateFlow(0)
    val unreadNotificationsCount: StateFlow<Int> = _unreadNotificationsCount.asStateFlow()

    init {
        checkAuth()
    }

    fun checkAuth() {
        viewModelScope.launch {
            val tokens = tokenManager.restoreTokens()
            if (tokens != null) {
                _isAuthenticated.value = true
                fetchUserProfile()
            } else {
                _isAuthenticated.value = false
            }
        }
    }

    fun signIn(email: String, password: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            val normalizedEmail = email.trim().lowercase()

            try {
                val response = apiClient.supabaseAuth.signIn(
                    SignInRequest(normalizedEmail, password)
                )
                tokenManager.saveTokens(response.accessToken, response.refreshToken)
                _isAuthenticated.value = true
                fetchUserProfile()
            } catch (e: Exception) {
                Log.e(TAG, "Sign in failed: ${e.message}", e)
                _errorMessage.value = mapErrorMessage(e.message ?: e.toString())
            } finally {
                _isLoading.value = false
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
        photoData: ByteArray? = null
    ) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
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
                } else {
                    // Try signing in directly if email confirmation is not forced
                    val loginResponse = apiClient.supabaseAuth.signIn(
                        com.example.zholdas.data.model.SignInRequest(normalizedEmail, password)
                    )
                    tokenManager.saveTokens(loginResponse.accessToken, loginResponse.refreshToken)
                    _isAuthenticated.value = true
                }

                if (_isAuthenticated.value) {
                    var finalAvatarURL = avatarURL ?: ""
                    
                    if (photoData != null) {
                        try {
                            val requestBody = photoData.toRequestBody("image/jpeg".toMediaType())
                            val part = MultipartBody.Part.createFormData("file", "avatar.jpg", requestBody)
                            val uploadResponse = apiClient.apiService.uploadImage(part)
                            finalAvatarURL = apiClient.backendBaseUrl + uploadResponse.url
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to upload avatar: ${e.message}", e)
                        }
                    }

                    if (finalAvatarURL.isNotEmpty() || !bio.isNullOrEmpty() || !city.isNullOrEmpty()) {
                        try {
                            val currentProfile = apiClient.apiService.getProfile()
                            apiClient.apiService.updateProfile(
                                com.example.zholdas.data.model.UpdateProfileRequest(
                                    fullName = fullName,
                                    bio = if (!bio.isNullOrEmpty()) bio else currentProfile.bio,
                                    city = if (!city.isNullOrEmpty()) city else currentProfile.city ?: "Алматы",
                                    avatarURL = if (finalAvatarURL.isNotEmpty()) finalAvatarURL else currentProfile.avatarURL
                                )
                            )
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to update profile: ${e.message}", e)
                        }
                    }
                    
                    fetchUserProfile()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Sign up failed: ${e.message}", e)
                _errorMessage.value = mapErrorMessage(e.message ?: e.toString())
            } finally {
                _isLoading.value = false
            }
        }
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
                _errorMessage.value = mapErrorMessage(e.message ?: e.toString())
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
            _errorMessage.value = mapErrorMessage(e.message ?: e.toString())
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
                apiClient.apiService.registerDeviceToken(DeviceTokenRequest("")) // Clear device token
                apiClient.apiService.logout()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to clear device token or logout on server: ${e.message}")
            }

            tokenManager.clearTokens()
            _currentUserProfile.value = null
            _isAuthenticated.value = false
            _isLoading.value = false
        }
    }

    fun fetchUserProfile() {
        viewModelScope.launch {
            try {
                val profile = apiClient.apiService.getProfile()
                _currentUserProfile.value = profile
                fetchNotificationsCount()
                registerDeviceToken()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to fetch user profile: ${e.message}", e)
                _errorMessage.value = "Сессия истекла. Войдите заново"
                tokenManager.clearTokens()
                _isAuthenticated.value = false
                _currentUserProfile.value = null
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
            _errorMessage.value = e.message
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
            _errorMessage.value = e.message
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

    private fun mapErrorMessage(message: String): String {
        return when {
            message.contains("Invalid login credentials") -> "Неверная почта или пароль"
            message.contains("Email not confirmed") -> "Подтвердите email перед входом"
            message.contains("Signup is disabled") -> "Регистрация отключена"
            else -> message
        }
    }

    fun clearError() {
        _errorMessage.value = null
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
