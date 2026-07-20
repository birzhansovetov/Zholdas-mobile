package com.example.zholdas.ui.screens.events

import android.content.ContentResolver
import android.net.Uri
import com.example.zholdas.data.remote.APIClient
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody

object EventImageUploader {
    const val MAX_IMAGE_BYTES: Long = 10L * 1024L * 1024L

    suspend fun upload(contentResolver: ContentResolver, uri: Uri, apiClient: APIClient): String {
        val declaredSize = contentResolver.openAssetFileDescriptor(uri, "r")?.use { it.length }
        require(declaredSize == null || declaredSize < 0 || declaredSize <= MAX_IMAGE_BYTES) {
            "Image is larger than 10 MB"
        }
        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: error("Unable to read selected image")
        require(bytes.size <= MAX_IMAGE_BYTES) { "Image is larger than 10 MB" }

        val mimeType = normalizeMimeType(contentResolver.getType(uri))
        val body = bytes.toRequestBody(mimeType.toMediaType())
        val part = MultipartBody.Part.createFormData(
            "file",
            "event.${extensionForMimeType(mimeType)}",
            body
        )
        val uploadedPath = apiClient.apiService.uploadImage(part).url
        return resolveUploadedUrl(apiClient.backendBaseUrl, uploadedPath)
    }

    fun normalizeMimeType(value: String?): String = when (value?.lowercase()) {
        "image/png" -> "image/png"
        "image/webp" -> "image/webp"
        "image/heic", "image/heif" -> "image/heic"
        else -> "image/jpeg"
    }

    fun extensionForMimeType(mimeType: String): String = when (normalizeMimeType(mimeType)) {
        "image/png" -> "png"
        "image/webp" -> "webp"
        "image/heic" -> "heic"
        else -> "jpg"
    }

    fun resolveUploadedUrl(baseUrl: String, uploadedPath: String): String {
        require(uploadedPath.isNotBlank()) { "Server returned an empty image URL" }
        return if (uploadedPath.startsWith("https://") || uploadedPath.startsWith("http://")) uploadedPath
        else baseUrl.trimEnd('/') + "/" + uploadedPath.trimStart('/')
    }

    fun imageUrlForUpdate(existingUrl: String?, uploadedUrl: String?, selectedNewImage: Boolean): String? =
        if (selectedNewImage) uploadedUrl else existingUrl
}
