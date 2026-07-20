package com.example.zholdas.ui

import com.example.zholdas.data.model.Event
import java.util.Locale

data class ValidationResult(
    val isValid: Boolean,
    val errorMessage: String? = null
)

data class BioMetadata(
    val gender: String?,
    val birthYear: Int?,
    val bioText: String
)

data class AiCommandParseResult(
    val isAiCommand: Boolean,
    val cleanPrompt: String,
    val mentionedTag: String? = null
)

object AuthUseCases {
    fun validateSignIn(email: String, password: String): ValidationResult {
        val trimmedEmail = email.trim()
        if (trimmedEmail.isEmpty()) {
            return ValidationResult(false, "Email не может быть пустым")
        }
        if (!trimmedEmail.contains("@") || !trimmedEmail.contains(".")) {
            return ValidationResult(false, "Некорректный формат email")
        }
        if (password.isEmpty()) {
            return ValidationResult(false, "Пароль не может быть пустым")
        }
        return ValidationResult(true)
    }

    fun validateSignUp(
        email: String,
        password: String,
        confirmPassword: String,
        fullName: String
    ): ValidationResult {
        val emailValidation = validateSignIn(email, "placeholder")
        if (!emailValidation.isValid) {
            return emailValidation
        }
        if (fullName.trim().isEmpty()) {
            return ValidationResult(false, "Имя не может быть пустым")
        }
        if (password.length < 6) {
            return ValidationResult(false, "Пароль должен содержать минимум 6 символов")
        }
        if (password != confirmPassword) {
            return ValidationResult(false, "Пароли не совпадают")
        }
        return ValidationResult(true)
    }

    fun validateGenderAndAge(
        gender: String,
        age: Int,
        minAllowedAge: Int = 16,
        maxAllowedAge: Int = 100
    ): ValidationResult {
        val validGenders = setOf("Мужской", "Женский", "Не указывать")
        if (gender !in validGenders) {
            return ValidationResult(false, "Некорректный пол")
        }
        if (age < minAllowedAge) {
            return ValidationResult(false, "Возраст должен быть не менее $minAllowedAge лет")
        }
        if (age > maxAllowedAge) {
            return ValidationResult(false, "Указан некорректный возраст")
        }
        return ValidationResult(true)
    }

    fun formatBioWithMetadata(gender: String, birthYear: Int, rawBio: String): String {
        return "[gender:$gender][birth_year:$birthYear]$rawBio"
    }

    fun parseBioMetadata(formattedBio: String): BioMetadata {
        val genderRegex = Regex("\\[gender:([^\\]]+)\\]")
        val birthYearRegex = Regex("\\[birth_year:(\\d+)\\]")

        val genderMatch = genderRegex.find(formattedBio)
        val birthYearMatch = birthYearRegex.find(formattedBio)

        val gender = genderMatch?.groupValues?.get(1)
        val birthYear = birthYearMatch?.groupValues?.get(1)?.toIntOrNull()

        var cleanText = formattedBio
        genderMatch?.let { cleanText = cleanText.replace(it.value, "") }
        birthYearMatch?.let { cleanText = cleanText.replace(it.value, "") }

        return BioMetadata(gender = gender, birthYear = birthYear, bioText = cleanText.trim())
    }

    fun extractUsernameFromEmail(email: String): String {
        return email.substringBefore("@").trim()
    }
}

enum class FriendshipAction {
    SEND, ACCEPT, REJECT, BLOCK
}

object ProfileSocialUseCases {
    fun validateProfileUpdate(fullName: String, city: String?): ValidationResult {
        if (fullName.trim().isEmpty()) {
            return ValidationResult(false, "Имя пользователя не может быть пустым")
        }
        return ValidationResult(true)
    }

    fun normalizeCity(city: String?): String {
        return if (city.isNullOrBlank()) "Алматы" else city.trim()
    }

    fun canSendFriendRequest(
        currentUserId: String,
        targetUserId: String,
        currentStatus: String
    ): ValidationResult {
        if (currentUserId == targetUserId) {
            return ValidationResult(false, "Нельзя добавить самого себя в друзья")
        }
        if (currentStatus == "friends") {
            return ValidationResult(false, "Пользователь уже в друзьях")
        }
        if (currentStatus == "pending_sent") {
            return ValidationResult(false, "Заявка в друзья уже отправлена")
        }
        return ValidationResult(true)
    }

    fun getNextFriendshipStatus(action: FriendshipAction, currentStatus: String): String {
        return when (action) {
            FriendshipAction.SEND -> "pending_sent"
            FriendshipAction.ACCEPT -> "friends"
            FriendshipAction.REJECT -> "none"
            FriendshipAction.BLOCK -> "blocked"
        }
    }

    fun validateRateParticipant(rating: Int, comment: String?): ValidationResult {
        if (rating !in 1..5) {
            return ValidationResult(false, "Оценка должна быть от 1 до 5")
        }
        if (comment != null && comment.length > 500) {
            return ValidationResult(false, "Комментарий слишком длинный")
        }
        return ValidationResult(true)
    }
}

object EventsUseCases {
    fun filterEvents(events: List<Event>, category: String, searchQuery: String): List<Event> {
        return events.filter { event ->
            val matchesCat = matchesCategory(event.category, category)
            val matchesQuery = if (searchQuery.isBlank()) {
                true
            } else {
                val q = searchQuery.trim().lowercase(Locale.getDefault())
                event.title.lowercase(Locale.getDefault()).contains(q) ||
                        event.description.lowercase(Locale.getDefault()).contains(q) ||
                        event.locationName.lowercase(Locale.getDefault()).contains(q)
            }
            matchesCat && matchesQuery
        }
    }

    private fun matchesCategory(eventCategory: String, filterCategory: String): Boolean {
        if (filterCategory == "cat_all") return true

        val ec = eventCategory.lowercase(Locale.getDefault())
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

    fun validateCreateEvent(
        title: String,
        locationName: String,
        maxParticipants: Int,
        startTime: String,
        endTime: String
    ): ValidationResult {
        if (title.trim().isEmpty()) {
            return ValidationResult(false, "Название события не может быть пустым")
        }
        if (locationName.trim().isEmpty()) {
            return ValidationResult(false, "Укажите место проведения")
        }
        if (maxParticipants <= 0) {
            return ValidationResult(false, "Количество участников должно быть больше 0")
        }
        if (startTime.isBlank() || endTime.isBlank()) {
            return ValidationResult(false, "Укажите время начала и окончания события")
        }
        return ValidationResult(true)
    }

    fun applyEventEdit(
        original: Event,
        title: String,
        description: String,
        category: String,
        locationName: String,
        latitude: Double,
        longitude: Double,
        maxParticipants: Int,
        genderFilter: String? = original.genderFilter,
        minAge: Int? = original.minAge,
        maxAge: Int? = original.maxAge
    ): Event {
        return original.copy(
            title = title,
            description = description,
            category = category,
            locationName = locationName,
            latitude = latitude,
            longitude = longitude,
            maxParticipants = maxParticipants,
            genderFilter = genderFilter,
            minAge = minAge,
            maxAge = maxAge
        )
    }

    fun updateEventParticipation(event: Event, isJoined: Boolean): Event {
        val currentCount = event.participantsCount ?: 1
        val newCount = if (isJoined) currentCount + 1 else (currentCount - 1).coerceAtLeast(0)
        return event.copy(isJoined = isJoined, participantsCount = newCount)
    }
}

object ChatAIUseCases {
    fun parseAiCommand(text: String): AiCommandParseResult {
        val cleanText = text.trim()
        val mentionsAI = cleanText.contains("@ai", ignoreCase = true) ||
                cleanText.contains("@жорик", ignoreCase = true) ||
                cleanText.contains("@zhorik", ignoreCase = true)

        if (!mentionsAI) {
            return AiCommandParseResult(isAiCommand = false, cleanPrompt = cleanText)
        }

        var tagFound: String? = null
        listOf("@ai", "@жорик", "@zhorik").forEach { tag ->
            if (cleanText.contains(tag, ignoreCase = true) && tagFound == null) {
                tagFound = tag
            }
        }

        val prompt = cleanText
            .replace("@ai", "", ignoreCase = true)
            .replace("@жорик", "", ignoreCase = true)
            .replace("@zhorik", "", ignoreCase = true)
            .trim()

        val resolvedPrompt = if (prompt.isEmpty()) {
            "Расскажи совет для нашей встречи в Алматы"
        } else {
            prompt
        }

        return AiCommandParseResult(
            isAiCommand = true,
            cleanPrompt = resolvedPrompt,
            mentionedTag = tagFound
        )
    }

    fun generateZhorikReply(prompt: String): String {
        val lower = prompt.lowercase(Locale.getDefault())
        return when {
            lower.contains("выходн") || lower.contains("куда") || lower.contains("weekend") ->
                "В эти выходные в Алматы отлично подойдет поход на Кок-Жайляу утром, а вечером — настольные игры в антикафе на Панфилова. Загляни во вкладку «События», там уже создано несколько групп!"
            lower.contains("спорт") || lower.contains("бег") || lower.contains("running") ->
                "Любители бега собираются в Парке Первого Президента каждую среду и субботу в 19:00. Присоединяйся к чату пробежек, ребята собирают команду на 5 км!"
            lower.contains("настолк") || lower.contains("игр") || lower.contains("board") ->
                "Отличная идея! В Алматы популярны вечера настольных игр в антикафе на Абая и Панфилова. Можешь создать событие в категории «Настольные игры»."
            else ->
                "Я Жорик, твой ИИ-помощник Жолдас! Подскажу интересные события в Алматы, помогу найти компанию для походов в горы, спорта или культурного отдыха."
        }
    }
}
