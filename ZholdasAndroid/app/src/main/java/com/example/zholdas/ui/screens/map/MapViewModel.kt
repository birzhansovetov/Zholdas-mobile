package com.example.zholdas.ui.screens.map

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.CreationExtras
import com.example.zholdas.ZholdasApplication
import com.example.zholdas.data.model.Event
import com.example.zholdas.data.remote.APIClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class MapUiState(
    val events: List<Event> = emptyList(),
    val filteredEvents: List<Event> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
    val selectedCategory: String = "cat_all",
    val selectedEvent: Event? = null,
    val searchQuery: String = "",
    val isFallbackMode: Boolean = false,
    val isAiLoading: Boolean = false,
    val aiAnswer: String? = null,
    val aiRecommendedEvents: List<Event> = emptyList(),
    val aiError: String? = null
)

class MapViewModel(
    private val apiClient: APIClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(MapUiState())
    val uiState: StateFlow<MapUiState> = _uiState.asStateFlow()

    init {
        loadNearbyEvents()
    }

    fun loadNearbyEvents(
        latitude: Double = DEFAULT_LATITUDE,
        longitude: Double = DEFAULT_LONGITUDE,
        radiusMeters: Double = DEFAULT_RADIUS_METERS
    ) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }
            try {
                val fetchedEvents = apiClient.apiService.getNearbyEvents(
                    latitude = latitude,
                    longitude = longitude,
                    radiusMeters = radiusMeters
                )
                _uiState.update { state ->
                    val updatedFiltered = filterEvents(
                        events = fetchedEvents,
                        category = state.selectedCategory,
                        query = state.searchQuery
                    )
                    state.copy(
                        events = fetchedEvents,
                        filteredEvents = updatedFiltered,
                        isLoading = false,
                        errorMessage = null
                    )
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to load nearby events via APIClient", e)
                _uiState.update { state ->
                    val updatedFiltered = filterEvents(
                        events = emptyList(),
                        category = state.selectedCategory,
                        query = state.searchQuery
                    )
                    state.copy(
                        events = emptyList(),
                        filteredEvents = updatedFiltered,
                        isLoading = false,
                        errorMessage = "Офлайн-режим: показаны события Алматы"
                    )
                }
            }
        }
    }

    fun selectCategory(category: String) {
        _uiState.update { state ->
            val updatedFiltered = filterEvents(
                events = state.events,
                category = category,
                query = state.searchQuery
            )
            state.copy(
                selectedCategory = category,
                filteredEvents = updatedFiltered
            )
        }
    }

    fun updateSearchQuery(query: String) {
        _uiState.update { state ->
            val updatedFiltered = filterEvents(
                events = state.events,
                category = state.selectedCategory,
                query = query
            )
            state.copy(
                searchQuery = query,
                filteredEvents = updatedFiltered
            )
        }
    }

    fun requestAIRecommendations(
        latitude: Double = DEFAULT_LATITUDE,
        longitude: Double = DEFAULT_LONGITUDE,
        radiusMeters: Double = DEFAULT_RADIUS_METERS
    ) {
        val query = _uiState.value.searchQuery.trim()
        if (query.isEmpty()) {
            _uiState.update { it.copy(aiError = "Опишите, какое событие вы ищете") }
            return
        }
        viewModelScope.launch {
            _uiState.update { it.copy(isAiLoading = true, aiError = null, aiAnswer = null, aiRecommendedEvents = emptyList()) }
            try {
                val response = apiClient.apiService.getAIRecommendations(query, latitude, longitude, radiusMeters)
                _uiState.update { state ->
                    state.copy(
                        isAiLoading = false,
                        aiAnswer = response.answer,
                        aiRecommendedEvents = resolveRecommendations(state.events, response.recommendedCardIDs),
                        aiError = null
                    )
                }
            } catch (e: Exception) {
                Log.w(TAG, "AI recommendations failed", e)
                _uiState.update { it.copy(isAiLoading = false, aiError = "Не удалось получить рекомендации. Проверьте подключение.") }
            }
        }
    }

    fun dismissAIRecommendations() {
        _uiState.update { it.copy(aiAnswer = null, aiRecommendedEvents = emptyList(), aiError = null) }
    }

    fun selectEvent(event: Event?) {
        _uiState.update { it.copy(selectedEvent = event) }
    }

    fun toggleFallbackMode() {
        _uiState.update { it.copy(isFallbackMode = !it.isFallbackMode) }
    }

    fun setFallbackMode(enabled: Boolean) {
        _uiState.update { it.copy(isFallbackMode = enabled) }
    }

    private fun filterEvents(
        events: List<Event>,
        category: String,
        query: String
    ): List<Event> {
        return events.filter { event ->
            val matchesCat = matchesCategory(event.category, category)
            val matchesText = query.isBlank() ||
                    event.title.contains(query, ignoreCase = true) ||
                    event.description.contains(query, ignoreCase = true) ||
                    event.locationName.contains(query, ignoreCase = true)
            matchesCat && matchesText
        }
    }

    companion object {
        private const val TAG = "MapViewModel"
        const val DEFAULT_LATITUDE = 43.2389
        const val DEFAULT_LONGITUDE = 76.8897
        const val DEFAULT_RADIUS_METERS = 10000.0

        val categories = listOf(
            "cat_all",
            "cat_mountains",
            "cat_theater",
            "cat_restaurant",
            "cat_sports",
            "cat_other"
        )

        fun matchesCategory(eventCategory: String, filterCategory: String): Boolean {
            if (filterCategory == "cat_all") return true
            val ec = eventCategory.lowercase()
            return when (filterCategory) {
                "cat_mountains" -> ec.contains("hiking") || ec.contains("mountain") || ec.contains("гор")
                "cat_theater" -> ec.contains("theater") || ec.contains("theatre") || ec.contains("театр")
                "cat_restaurant" -> ec.contains("restaurant") || ec.contains("food") || ec.contains("cafe") || ec.contains("ресторан") || ec.contains("кафе")
                "cat_sports" -> ec.contains("sport") || ec.contains("run") || ec.contains("football") || ec.contains("спорт") || ec.contains("футбол")
                "cat_other" -> {
                    val matchesSpecific = ec.contains("hiking") || ec.contains("mountain") || ec.contains("гор") ||
                            ec.contains("theater") || ec.contains("theatre") || ec.contains("театр") ||
                            ec.contains("restaurant") || ec.contains("food") || ec.contains("cafe") || ec.contains("ресторан") || ec.contains("кафе") ||
                            ec.contains("sport") || ec.contains("run") || ec.contains("football") || ec.contains("спорт") || ec.contains("футбол")
                    !matchesSpecific
                }
                else -> false
            }
        }

        fun resolveRecommendations(events: List<Event>, recommendedIds: List<Int>): List<Event> {
            val byId = events.associateBy(Event::id)
            return recommendedIds.distinct().mapNotNull(byId::get)
        }

        fun provideFactory(apiClient: APIClient): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    return MapViewModel(apiClient) as T
                }
            }

        val Factory: ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>, extras: CreationExtras): T {
                val application = checkNotNull(extras[APPLICATION_KEY]) as ZholdasApplication
                return MapViewModel(application.container.apiClient) as T
            }
        }
    }
}
