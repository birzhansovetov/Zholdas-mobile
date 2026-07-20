package com.example.zholdas.data.local

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicLong

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "auth_prefs")

class TokenManager(private val context: Context) {
    private val cache = InMemoryTokenCache()
    private val persistenceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val persistenceVersion = AtomicLong(0)

    companion object {
        private val ACCESS_TOKEN_KEY = stringPreferencesKey("access_token")
        private val REFRESH_TOKEN_KEY = stringPreferencesKey("refresh_token")
    }

    val accessToken: Flow<String?> = context.dataStore.data.map { preferences ->
        preferences[ACCESS_TOKEN_KEY]
    }

    val refreshToken: Flow<String?> = context.dataStore.data.map { preferences ->
        preferences[REFRESH_TOKEN_KEY]
    }

    init {
        persistenceScope.launch {
            val preferences = context.dataStore.data.first()
            initializeCache(preferences[ACCESS_TOKEN_KEY], preferences[REFRESH_TOKEN_KEY])
        }
    }

    fun currentTokens(): TokenSnapshot? = cache.snapshot()

    suspend fun restoreTokens(): TokenSnapshot? {
        val preferences = context.dataStore.data.first()
        initializeCache(preferences[ACCESS_TOKEN_KEY], preferences[REFRESH_TOKEN_KEY])
        return cache.snapshot()
    }

    suspend fun saveTokens(accessToken: String, refreshToken: String) {
        persistenceVersion.incrementAndGet()
        cache.update(accessToken, refreshToken)
        context.dataStore.edit { preferences ->
            preferences[ACCESS_TOKEN_KEY] = accessToken
            preferences[REFRESH_TOKEN_KEY] = refreshToken
        }
    }

    suspend fun clearTokens() {
        persistenceVersion.incrementAndGet()
        cache.clear()
        context.dataStore.edit { preferences ->
            preferences.remove(ACCESS_TOKEN_KEY)
            preferences.remove(REFRESH_TOKEN_KEY)
        }
    }

    /** Used by OkHttp's synchronous Authenticator after a synchronous token refresh. */
    fun saveTokensFromSyncContext(accessToken: String, refreshToken: String) {
        val version = persistenceVersion.incrementAndGet()
        cache.update(accessToken, refreshToken)
        persistenceScope.launch {
            if (version != persistenceVersion.get()) return@launch
            context.dataStore.edit { preferences ->
                preferences[ACCESS_TOKEN_KEY] = accessToken
                preferences[REFRESH_TOKEN_KEY] = refreshToken
            }
        }
    }

    /** Clears authorization immediately, then removes persisted values off the OkHttp thread. */
    fun clearTokensFromSyncContext() {
        val version = persistenceVersion.incrementAndGet()
        cache.clear()
        persistenceScope.launch {
            if (version != persistenceVersion.get()) return@launch
            context.dataStore.edit { preferences ->
                preferences.remove(ACCESS_TOKEN_KEY)
                preferences.remove(REFRESH_TOKEN_KEY)
            }
        }
    }

    private fun initializeCache(accessToken: String?, refreshToken: String?) {
        if (!accessToken.isNullOrBlank() && !refreshToken.isNullOrBlank()) {
            cache.initializeIfEmpty(accessToken, refreshToken)
        }
    }
}
