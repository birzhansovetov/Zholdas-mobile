package com.example.zholdas

import androidx.navigation3.runtime.NavKey
import kotlinx.serialization.Serializable

@Serializable data object Main : NavKey
@Serializable data object Login : NavKey
@Serializable data object Register : NavKey
@Serializable data object ForgotPassword : NavKey
@Serializable data object MainAppShell : NavKey
@Serializable data class EventDetails(val id: Int) : NavKey
@Serializable data class ChatRoom(val id: Int) : NavKey
@Serializable data object EditProfile : NavKey
@Serializable data object FriendsList : NavKey
@Serializable data class UserProfileDetail(val userId: String) : NavKey
@Serializable data class RateEventParticipants(val eventId: Int) : NavKey
