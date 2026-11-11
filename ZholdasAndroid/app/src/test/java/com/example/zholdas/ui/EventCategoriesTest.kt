package com.example.zholdas.ui

import com.example.zholdas.ui.screens.map.EventCategories
import com.example.zholdas.ui.screens.map.MapViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EventCategoriesTest {

    @Test
    fun testCatAll_matchesEverything() {
        assertTrue(EventCategories.matches("hiking", "cat_all"))
        assertTrue(EventCategories.matches("sports", "cat_all"))
        assertTrue(EventCategories.matches("random_unknown_cat", "cat_all"))
    }

    @Test
    fun testMountains_exactMatchAndLegacy() {
        assertTrue(EventCategories.matches("hiking", "cat_mountains"))
        assertTrue(EventCategories.matches("walk", "cat_mountains"))
        assertTrue(EventCategories.matches("cat_mountains", "cat_mountains"))
        assertTrue(EventCategories.matches("  HIKING  ", "cat_mountains"))

        // Substring / substring matches should not match in exact matching
        assertFalse(EventCategories.matches("Mountain hike", "cat_mountains"))
        assertFalse(EventCategories.matches("gory", "cat_mountains"))
    }

    @Test
    fun testTheater_exactMatchAndLegacy() {
        assertTrue(EventCategories.matches("theater", "cat_theater"))
        assertTrue(EventCategories.matches("cat_theater", "cat_theater"))
        assertFalse(EventCategories.matches("movie", "cat_theater"))
    }

    @Test
    fun testRestaurant_exactMatchAndLegacy() {
        assertTrue(EventCategories.matches("restaurant", "cat_restaurant"))
        assertTrue(EventCategories.matches("cat_restaurant", "cat_restaurant"))
        assertFalse(EventCategories.matches("food court", "cat_restaurant"))
    }

    @Test
    fun testSports_exactMatchAndLegacy() {
        assertTrue(EventCategories.matches("sports", "cat_sports"))
        assertTrue(EventCategories.matches("cat_sports", "cat_sports"))
        assertFalse(EventCategories.matches("football match", "cat_sports"))
    }

    @Test
    fun testOther_matchesNonSpecificAndLegacy() {
        assertTrue(EventCategories.matches("board_games", "cat_other"))
        assertTrue(EventCategories.matches("networking", "cat_other"))
        assertTrue(EventCategories.matches("cat_other", "cat_other"))
        assertTrue(EventCategories.matches("pottery", "cat_other"))

        // Specific categories should not match cat_other
        assertFalse(EventCategories.matches("hiking", "cat_other"))
        assertFalse(EventCategories.matches("walk", "cat_other"))
        assertFalse(EventCategories.matches("theater", "cat_other"))
        assertFalse(EventCategories.matches("restaurant", "cat_other"))
        assertFalse(EventCategories.matches("sports", "cat_other"))
    }

    @Test
    fun testMapViewModelDelegation() {
        assertTrue(MapViewModel.matchesCategory("hiking", "cat_mountains"))
        assertTrue(MapViewModel.matchesCategory("sports", "cat_sports"))
        assertTrue(MapViewModel.matchesCategory("board_games", "cat_other"))
        assertFalse(MapViewModel.matchesCategory("sports", "cat_mountains"))
    }

    @Test
    fun testGetFilterKey() {
        assertEquals("cat_all", EventCategories.getFilterKey("cat_all"))
        assertEquals("cat_mountains", EventCategories.getFilterKey("hiking"))
        assertEquals("cat_mountains", EventCategories.getFilterKey("walk"))
        assertEquals("cat_theater", EventCategories.getFilterKey("theater"))
        assertEquals("cat_restaurant", EventCategories.getFilterKey("restaurant"))
        assertEquals("cat_sports", EventCategories.getFilterKey("sports"))
        assertEquals("cat_other", EventCategories.getFilterKey("board_games"))
        assertEquals("cat_other", EventCategories.getFilterKey("networking"))
        assertEquals("cat_other", EventCategories.getFilterKey("unknown"))
    }
}
