package com.example.zholdas.data.remote

import com.example.zholdas.data.local.localized
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import retrofit2.HttpException
import java.io.IOException

private val jsonParser = Json {
    ignoreUnknownKeys = true
    isLenient = true
}

fun Throwable.toUserMessage(fallbackKey: String = "error_generic"): String {
    return when (this) {
        is HttpException -> parseHttpException(fallbackKey)
        is IOException -> "error_network".localized
        else -> fallbackKey.localized
    }
}

private fun HttpException.parseHttpException(fallbackKey: String): String {
    val statusCode = code()

    val rawJson = try {
        response()?.errorBody()?.string()
    } catch (_: Exception) {
        null
    }

    val jsonObject = if (!rawJson.isNullOrBlank()) {
        try {
            jsonParser.parseToJsonElement(rawJson) as? JsonObject
        } catch (_: Exception) {
            null
        }
    } else {
        null
    }

    val errorCode = jsonObject.safeString("error_code")
    val msg = jsonObject.safeString("msg")
    val errorDescription = jsonObject.safeString("error_description")
    val error = jsonObject.safeString("error")

    // Supabase rate limit or HTTP 429
    if (statusCode == 429 ||
        errorCode == "over_request_rate_limit" ||
        errorCode == "over_email_send_rate_limit" ||
        error == "over_request_rate_limit" ||
        error == "over_email_send_rate_limit"
    ) {
        return "error_rate_limit".localized
    }

    // Supabase known auth error codes
    val isInvalidCredentials = errorCode == "invalid_credentials" ||
        error == "invalid_credentials" ||
        error == "invalid_grant" ||
        msg?.contains("Invalid login credentials", ignoreCase = true) == true ||
        errorDescription?.contains("Invalid login credentials", ignoreCase = true) == true

    if (isInvalidCredentials) {
        return "error_invalid_credentials".localized
    }

    val isEmailNotConfirmed = errorCode == "email_not_confirmed" ||
        error == "email_not_confirmed" ||
        msg?.contains("Email not confirmed", ignoreCase = true) == true ||
        errorDescription?.contains("Email not confirmed", ignoreCase = true) == true

    if (isEmailNotConfirmed) {
        return "error_email_not_confirmed".localized
    }

    val isUserAlreadyExists = errorCode == "user_already_exists" ||
        error == "user_already_exists" ||
        msg?.contains("User already registered", ignoreCase = true) == true ||
        errorDescription?.contains("User already registered", ignoreCase = true) == true

    if (isUserAlreadyExists) {
        return "error_user_already_exists".localized
    }

    val isWeakPassword = errorCode == "weak_password" ||
        error == "weak_password" ||
        msg?.contains("Password should be", ignoreCase = true) == true ||
        errorDescription?.contains("Password should be", ignoreCase = true) == true

    if (isWeakPassword) {
        return "error_weak_password".localized
    }

    // 401 Unauthorized -> session expired
    if (statusCode == 401 || error.equals("unauthorized", ignoreCase = true)) {
        return "session_expired".localized
    }

    // Backend error message
    if (!error.isNullOrBlank() && !error.equals("forbidden", ignoreCase = true)) {
        return error
    }

    // HTTP status codes fallback
    return when (statusCode) {
        403 -> "error_forbidden".localized
        404 -> "error_not_found".localized
        in 500..599 -> "error_server_unavailable".localized
        else -> fallbackKey.localized
    }
}

private fun JsonObject?.safeString(key: String): String? {
    return try {
        this?.get(key)?.jsonPrimitive?.contentOrNull?.trim()
    } catch (_: Exception) {
        null
    }
}
