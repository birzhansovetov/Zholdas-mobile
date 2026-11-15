package com.example.zholdas.ui.screens.events

import android.content.ContentResolver
import android.net.Uri
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.zholdas.data.model.CreateEventRequest
import com.example.zholdas.data.model.Event
import com.example.zholdas.data.model.EventLiveLocation
import com.example.zholdas.data.model.LocationRequest
import com.example.zholdas.data.model.Participant
import com.example.zholdas.data.model.ParticipantStatusRequest
import com.example.zholdas.data.model.User
import com.example.zholdas.data.remote.APIClient
import com.example.zholdas.data.remote.toUserMessage
import com.example.zholdas.ui.screens.map.EventCategories
import com.example.zholdas.ui.screens.map.MapViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.Locale

class EventsViewModel(
    private val apiClient: APIClient
) : ViewModel() {

    suspend fun uploadEventImage(contentResolver: ContentResolver, uri: Uri): String =
        EventImageUploader.upload(contentResolver, uri, apiClient)

    companion object {
        private const val TAG = "EventsViewModel"
    }

    private val _events = MutableStateFlow<List<Event>>(emptyList())
    val events: StateFlow<List<Event>> = _events.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isRefreshing = MutableStateFlow(false)
    val isRefreshing: StateFlow<Boolean> = _isRefreshing.asStateFlow()

    private var lastLatitude: Double = MapViewModel.DEFAULT_LATITUDE
    private var lastLongitude: Double = MapViewModel.DEFAULT_LONGITUDE

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _selectedCategory = MutableStateFlow("cat_all")
    val selectedCategory: StateFlow<String> = _selectedCategory.asStateFlow()

    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    private val _recommendedEventIDs = MutableStateFlow<Set<Int>>(emptySet())
    val recommendedEventIDs: StateFlow<Set<Int>> = _recommendedEventIDs.asStateFlow()

    private val _currentUserID = MutableStateFlow("")
    val currentUserID: StateFlow<String> = _currentUserID.asStateFlow()

    private val _organizerProfile = MutableStateFlow<User?>(null)
    val organizerProfile: StateFlow<User?> = _organizerProfile.asStateFlow()

    fun loadOrganizer(creatorId: String) {
        _organizerProfile.value = null
        viewModelScope.launch {
            if (creatorId.isBlank()) return@launch
            try {
                val fetched = apiClient.apiService.getUserProfileByID(creatorId)
                _organizerProfile.value = fetched
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load organizer profile: ${e.message}", e)
            }
        }
    }

    suspend fun loadCurrentUser() {
        if (_currentUserID.value.isNotBlank()) return
        try {
            _currentUserID.value = apiClient.apiService.getProfile().id
        } catch (e: Exception) {
            _errorMessage.value = e.toUserMessage()
        }
    }

    suspend fun eventReminderText(eventId: Int): String? = try {
        apiClient.apiService.getNotifications()
            .firstOrNull { it.eventID == eventId && it.notificationType == "event_reminder" }
            ?.text
    } catch (_: Exception) { null }

    val filteredEvents: StateFlow<List<Event>> = combine(
        _events,
        _selectedCategory,
        _searchQuery
    ) { list, category, query ->
        list.filter { event ->
            val matchesCat = matchesCategory(event.category, category)
            val matchesQuery = if (query.isBlank()) {
                true
            } else {
                val q = query.trim().lowercase(Locale.getDefault())
                event.title.lowercase(Locale.getDefault()).contains(q) ||
                    event.description.lowercase(Locale.getDefault()).contains(q) ||
                    event.locationName.lowercase(Locale.getDefault()).contains(q)
            }
            matchesCat && matchesQuery
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    init {
        loadEvents()
    }

    fun selectCategory(category: String) {
        _selectedCategory.value = category
    }

    fun updateSearchQuery(query: String) {
        _searchQuery.value = query
    }

    fun clearError() {
        _errorMessage.value = null
    }

    fun refresh() {
        loadEvents(lastLatitude, lastLongitude, isRefresh = true)
    }

    fun loadEvents(
        latitude: Double = MapViewModel.DEFAULT_LATITUDE,
        longitude: Double = MapViewModel.DEFAULT_LONGITUDE,
        isRefresh: Boolean = false
    ) {
        lastLatitude = latitude
        lastLongitude = longitude
        viewModelScope.launch {
            if (isRefresh) {
                _isRefreshing.value = true
            } else {
                _isLoading.value = true
            }
            _errorMessage.value = null
            try {
                val fetched = apiClient.apiService.getNearbyEvents(
                    latitude = latitude,
                    longitude = longitude,
                    radiusMeters = MapViewModel.EVENTS_RADIUS_METERS
                )
                _events.value = fetched
            } catch (e: Exception) {
                Log.w(TAG, "Failed to load events from API: ${e.message}")
                _errorMessage.value = e.toUserMessage()
            } finally {
                if (isRefresh) {
                    _isRefreshing.value = false
                } else {
                    _isLoading.value = false
                }
            }
        }
    }

    fun joinEvent(eventId: Int, onResult: ((Boolean) -> Unit)? = null) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            try {
                apiClient.apiService.joinEvent(eventId)
                updateEventParticipationLocally(eventId, isJoined = true)
                onResult?.invoke(true)
            } catch (e: Exception) {
                Log.w(TAG, "joinEvent API error: ${e.message}")
                _errorMessage.value = e.toUserMessage()
                onResult?.invoke(false)
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun leaveEvent(eventId: Int, onResult: ((Boolean) -> Unit)? = null) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            try {
                apiClient.apiService.leaveEvent(eventId)
                updateEventParticipationLocally(eventId, isJoined = false)
                onResult?.invoke(true)
            } catch (e: Exception) {
                Log.w(TAG, "leaveEvent API error: ${e.message}")
                _errorMessage.value = e.toUserMessage()
                onResult?.invoke(false)
            } finally {
                _isLoading.value = false
            }
        }
    }

    suspend fun fetchParticipants(eventId: Int): List<Participant> {
        return try {
            apiClient.apiService.getEventParticipants(eventId)
        } catch (e: Exception) {
            Log.w(TAG, "fetchParticipants error: ${e.message}")
            _errorMessage.value = e.toUserMessage()
            emptyList()
        }
    }

    suspend fun fetchCurrentParticipantStatus(eventId: Int, participants: List<Participant>): String {
        return try {
            val currentUserID = apiClient.apiService.getProfile().id
            participants.firstOrNull { it.id == currentUserID }?.participantStatus ?: "going"
        } catch (_: Exception) {
            "going"
        }
    }

    suspend fun updateParticipantStatus(eventId: Int, status: String): Boolean = try {
        _errorMessage.value = null
        apiClient.apiService.updateParticipantStatus(eventId, ParticipantStatusRequest(status))
        true
    } catch (e: Exception) {
        _errorMessage.value = e.toUserMessage()
        false
    }

    suspend fun markArrived(eventId: Int, latitude: Double, longitude: Double, accuracy: Double?): Boolean = try {
        _errorMessage.value = null
        apiClient.apiService.markArrived(eventId, LocationRequest(latitude, longitude, accuracy))
        true
    } catch (e: Exception) {
        _errorMessage.value = e.toUserMessage()
        false
    }

    suspend fun updateLiveLocation(eventId: Int, latitude: Double, longitude: Double, accuracy: Double?): Boolean = try {
        _errorMessage.value = null
        apiClient.apiService.updateLiveLocation(eventId, LocationRequest(latitude, longitude, accuracy))
        true
    } catch (e: Exception) {
        _errorMessage.value = e.toUserMessage()
        false
    }

    suspend fun fetchLiveLocations(eventId: Int): List<EventLiveLocation> = try {
        apiClient.apiService.getLiveLocations(eventId)
    } catch (e: Exception) {
        _errorMessage.value = e.toUserMessage()
        emptyList()
    }

    suspend fun stopLiveLocation(eventId: Int): Boolean = try {
        apiClient.apiService.stopLiveLocation(eventId)
        true
    } catch (e: Exception) {
        _errorMessage.value = e.toUserMessage()
        false
    }

    fun createEvent(
        title: String,
        description: String,
        category: String,
        locationName: String,
        latitude: Double,
        longitude: Double,
        startTime: String,
        endTime: String,
        maxParticipants: Int,
        imageURL: String? = null,
        visibility: String? = "public",
        genderFilter: String? = "all",
        minAge: Int? = null,
        maxAge: Int? = null,
        onResult: ((Boolean) -> Unit)? = null
    ) {
        viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            try {
                val req = CreateEventRequest(
                    title = title,
                    description = description,
                    category = category,
                    locationName = locationName,
                    latitude = latitude,
                    longitude = longitude,
                    startTime = startTime,
                    endTime = endTime,
                    maxParticipants = maxParticipants,
                    imageURL = imageURL,
                    visibility = visibility,
                    genderFilter = genderFilter,
                    minAge = minAge,
                    maxAge = maxAge
                )
                val created = apiClient.apiService.createEvent(req)
                _events.value = listOf(created) + _events.value
                onResult?.invoke(true)
            } catch (e: Exception) {
                Log.w(TAG, "createEvent API error: ${e.message}")
                _errorMessage.value = e.toUserMessage()
                onResult?.invoke(false)
            } finally {
                _isLoading.value = false
            }
        }
    }

    private fun updateEventParticipationLocally(eventId: Int, isJoined: Boolean) {
        _events.value = applyParticipationResponse(_events.value, eventId, isJoined, requestSucceeded = true)
    }

    private fun matchesCategory(eventCategory: String, filterCategory: String): Boolean {
        return EventCategories.matches(eventCategory, filterCategory)
    }

    class Factory(private val apiClient: APIClient) : ViewModelProvider.Factory {
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            if (modelClass.isAssignableFrom(EventsViewModel::class.java)) {
                @Suppress("UNCHECKED_CAST")
                return EventsViewModel(apiClient) as T
            }
            throw IllegalArgumentException("Unknown ViewModel class")
        }
    }
}
