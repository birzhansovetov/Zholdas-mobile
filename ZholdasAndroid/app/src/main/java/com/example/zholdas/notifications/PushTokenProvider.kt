package com.example.zholdas.notifications

import android.util.Log
import com.google.firebase.messaging.FirebaseMessaging
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

interface PushTokenProvider {
    suspend fun currentToken(): String?
}

class FirebasePushTokenProvider : PushTokenProvider {
    override suspend fun currentToken(): String? = suspendCancellableCoroutine { continuation ->
        try {
            FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                if (!continuation.isActive) return@addOnCompleteListener
                if (task.isSuccessful) continuation.resume(task.result)
                else {
                    Log.w(TAG, "FCM token is unavailable", task.exception)
                    continuation.resume(null)
                }
            }
        } catch (error: IllegalStateException) {
            // Expected until the project owner adds google-services.json.
            Log.w(TAG, "Firebase is not configured; push registration skipped", error)
            continuation.resume(null)
        }
    }

    private companion object { const val TAG = "FirebasePushToken" }
}
