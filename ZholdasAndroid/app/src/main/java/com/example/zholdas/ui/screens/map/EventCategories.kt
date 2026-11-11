package com.example.zholdas.ui.screens.map

object EventCategories {
    val CATEGORY_MAPPINGS: Map<String, Set<String>> = mapOf(
        "cat_mountains" to setOf("hiking", "walk", "cat_mountains"),
        "cat_theater" to setOf("theater", "cat_theater"),
        "cat_restaurant" to setOf("restaurant", "cat_restaurant"),
        "cat_sports" to setOf("sports", "cat_sports")
    )

    private val KNOWN_SPECIFIC_CATEGORIES: Set<String> = CATEGORY_MAPPINGS.values.flatten().toSet()

    fun matches(eventCategory: String, filterCategory: String): Boolean {
        val filter = filterCategory.trim().lowercase()
        if (filter == "cat_all") return true

        val ec = eventCategory.trim().lowercase()
        val mappedSet = CATEGORY_MAPPINGS[filter]
        if (mappedSet != null) {
            return ec in mappedSet
        }

        if (filter == "cat_other") {
            return ec == "cat_other" || ec !in KNOWN_SPECIFIC_CATEGORIES
        }

        return false
    }

    fun getFilterKey(eventCategory: String): String {
        val ec = eventCategory.trim().lowercase()
        if (ec == "cat_all") return "cat_all"
        for ((filter, set) in CATEGORY_MAPPINGS) {
            if (ec in set) return filter
        }
        return "cat_other"
    }
}
