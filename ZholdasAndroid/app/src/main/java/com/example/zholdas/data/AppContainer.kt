package com.example.zholdas.data

import android.content.Context
import com.example.zholdas.data.local.TokenManager
import com.example.zholdas.data.remote.APIClient
import com.example.zholdas.notifications.FirebasePushTokenProvider
import com.example.zholdas.notifications.PushTokenProvider

interface AppContainer {
    val tokenManager: TokenManager
    val apiClient: APIClient
    val pushTokenProvider: PushTokenProvider
}

class DefaultAppContainer(private val context: Context) : AppContainer {
    override val tokenManager: TokenManager by lazy {
        TokenManager(context)
    }

    override val apiClient: APIClient by lazy {
        APIClient(tokenManager)
    }
    override val pushTokenProvider: PushTokenProvider by lazy { FirebasePushTokenProvider() }
}
