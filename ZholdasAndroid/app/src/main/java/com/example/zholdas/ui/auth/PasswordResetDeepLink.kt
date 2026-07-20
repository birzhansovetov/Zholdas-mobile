package com.example.zholdas.ui.auth

import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets

data class PasswordResetLink(val accessToken: String? = null, val error: String? = null) {
    val isValid: Boolean get() = !accessToken.isNullOrBlank() && error == null
}

object PasswordResetDeepLink {
    fun parse(rawUrl: String?): PasswordResetLink? {
        if (rawUrl.isNullOrBlank()) return null
        val uri = runCatching { URI(rawUrl) }.getOrNull() ?: return null
        val isResetUrl = uri.scheme.equals("zholdas", ignoreCase = true) &&
            (uri.host.equals("reset-password", ignoreCase = true) || uri.path?.contains("reset-password") == true)
        if (!isResetUrl) return null

        val params = parseParameters(uri.rawQuery) + parseParameters(uri.rawFragment)
        val error = params["error_description"] ?: params["error"]
        if (error != null) return PasswordResetLink(error = error)
        if (params["type"] != "recovery") return PasswordResetLink(error = "Invalid or expired password reset link")
        val token = params["access_token"]
        return if (token.isNullOrBlank()) PasswordResetLink(error = "Invalid or expired password reset link")
        else PasswordResetLink(accessToken = token)
    }

    private fun parseParameters(raw: String?): Map<String, String> = raw
        ?.split('&')
        ?.mapNotNull { part ->
            val pieces = part.split('=', limit = 2)
            if (pieces.isEmpty() || pieces[0].isBlank()) null
            else decode(pieces[0]) to decode(pieces.getOrElse(1) { "" })
        }
        ?.toMap()
        .orEmpty()

    private fun decode(value: String): String =
        URLDecoder.decode(value, StandardCharsets.UTF_8.name())
}
