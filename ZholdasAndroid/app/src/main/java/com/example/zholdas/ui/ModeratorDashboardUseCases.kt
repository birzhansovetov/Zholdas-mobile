package com.example.zholdas.ui

import com.example.zholdas.data.model.*
import com.example.zholdas.data.remote.ZholdasApiService

class ModeratorDashboardUseCases(private val apiService: ZholdasApiService) {

    fun validateSettings(rateLimitText: String, defaultCity: String): ModerationSettingsValidation {
        val limit = rateLimitText.toIntOrNull()
        return when {
            limit == null || limit !in 1..100 -> ModerationSettingsValidation(false, "Лимит AI должен быть от 1 до 100")
            defaultCity.isBlank() -> ModerationSettingsValidation(false, "Город по умолчанию обязателен")
            else -> ModerationSettingsValidation(true, null, limit)
        }
    }

    suspend fun loadAuditLogs(actor: User): List<ModerationAuditLog> {
        require(isAdmin(actor)) { "Admin role required" }
        return apiService.getModerationAuditLogs()
    }

    suspend fun loadSettings(actor: User): ModerationSettings {
        require(isAdmin(actor)) { "Admin role required" }
        return apiService.getModerationSettings()
    }

    suspend fun saveSettings(actor: User, aiEnabled: Boolean, rateLimitText: String, defaultCity: String): ModerationSettings {
        require(isAdmin(actor)) { "Admin role required" }
        val validation = validateSettings(rateLimitText, defaultCity)
        require(validation.isValid) { validation.error ?: "Invalid settings" }
        return apiService.updateModerationSettings(
            ModerationSettings(aiEnabled, validation.rateLimit!!, defaultCity.trim())
        )
    }

    fun isAdmin(user: User?): Boolean {
        return user?.role?.equals("admin", ignoreCase = true) == true
    }

    fun isModeratorOrAdmin(user: User?): Boolean {
        val role = user?.role ?: return false
        return role.equals("admin", ignoreCase = true) || role.equals("moderator", ignoreCase = true)
    }

    fun canBanUser(actor: User?, target: User?): Boolean {
        if (actor == null || target == null) return false
        if (!isModeratorOrAdmin(actor)) return false
        // Moderator cannot ban an admin or another moderator
        if (!isAdmin(actor) && isModeratorOrAdmin(target)) return false
        // Cannot ban self
        return actor.id != target.id
    }

    fun canUpdateUserRole(actor: User?, target: User?): Boolean {
        if (actor == null || target == null) return false
        if (!isAdmin(actor)) return false
        return actor.id != target.id
    }

    suspend fun banUser(userId: String, reason: String): GenericMessageResponse {
        require(userId.isNotBlank()) { "User ID cannot be blank" }
        require(reason.isNotBlank()) { "Ban reason cannot be blank" }
        val request = BanRequest(reason = reason)
        return apiService.banUser(id = userId, request = request, reason = reason)
    }

    suspend fun unbanUser(userId: String): GenericMessageResponse {
        require(userId.isNotBlank()) { "User ID cannot be blank" }
        return apiService.unbanUser(id = userId)
    }

    suspend fun getModerationStats(): ModerationStats {
        return apiService.getModerationStats()
    }

    fun calculateActiveEventsRatio(stats: ModerationStats): Float {
        val eventCount = if (stats.events > 0) stats.events else stats.totalEvents
        if (eventCount <= 0) return 0f
        return (stats.activeEvents.toFloat() / eventCount.toFloat()) * 100f
    }

    suspend fun updateEventStatus(eventId: Int, newStatus: String): GenericMessageResponse {
        require(eventId > 0) { "Event ID must be positive" }
        // Must stay aligned with UpdateEventStatus in the Go moderation handler.
        val validStatuses = setOf("active", "closed", "cancelled", "deleted")
        require(newStatus.lowercase() in validStatuses) { "Invalid event status: $newStatus" }
        return apiService.updateEventStatus(id = eventId, request = StatusRequest(status = newStatus.lowercase()))
    }

    suspend fun updateUserRole(userId: String, newRole: String): GenericMessageResponse {
        require(userId.isNotBlank()) { "User ID cannot be blank" }
        val validRoles = setOf("user", "moderator", "admin")
        require(newRole.lowercase() in validRoles) { "Invalid role: $newRole" }
        return apiService.updateUserRole(id = userId, request = RoleRequest(role = newRole.lowercase()))
    }

    suspend fun closeReport(reportId: Int): GenericMessageResponse {
        require(reportId > 0) { "Report ID must be positive" }
        return apiService.closeReport(reportId)
    }
}

data class ModerationSettingsValidation(val isValid: Boolean, val error: String?, val rateLimit: Int? = null)
