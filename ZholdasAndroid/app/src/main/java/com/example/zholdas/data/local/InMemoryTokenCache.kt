package com.example.zholdas.data.local

import java.util.concurrent.atomic.AtomicReference

data class TokenSnapshot(val accessToken: String, val refreshToken: String)

class InMemoryTokenCache {
    private data class State(val initialized: Boolean, val snapshot: TokenSnapshot?)
    private val state = AtomicReference(State(initialized = false, snapshot = null))

    fun snapshot(): TokenSnapshot? = state.get().snapshot

    fun update(accessToken: String, refreshToken: String) {
        if (accessToken.isBlank() || refreshToken.isBlank()) {
            clear()
        } else {
            state.set(State(initialized = true, snapshot = TokenSnapshot(accessToken, refreshToken)))
        }
    }

    fun initializeIfEmpty(accessToken: String, refreshToken: String) {
        if (accessToken.isNotBlank() && refreshToken.isNotBlank()) {
            while (true) {
                val current = state.get()
                if (current.initialized) return
                if (state.compareAndSet(current, State(true, TokenSnapshot(accessToken, refreshToken)))) return
            }
        }
    }

    fun clear() {
        state.set(State(initialized = true, snapshot = null))
    }
}
