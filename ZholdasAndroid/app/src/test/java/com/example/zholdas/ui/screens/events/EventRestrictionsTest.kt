package com.example.zholdas.ui.screens.events

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class EventRestrictionsTest {

    private val prefix = "Restrictions: "
    private val menOnly = "Men only"
    private val womenOnly = "Women only"
    private val ageRangeFormat = "Ages %1\$d–%2\$d"
    private val ageFromFormat = "Ages %d+"
    private val ageToFormat = "Up to age %d"

    private fun format(genderFilter: String?, minAge: Int?, maxAge: Int?): String? {
        return EventUtils.formatRestrictions(
            genderFilter = genderFilter,
            minAge = minAge,
            maxAge = maxAge,
            prefix = prefix,
            menOnly = menOnly,
            womenOnly = womenOnly,
            ageRangeFormat = ageRangeFormat,
            ageFromFormat = ageFromFormat,
            ageToFormat = ageToFormat
        )
    }

    @Test
    fun noRestrictions_returnsNull() {
        assertNull(format(null, null, null))
        assertNull(format("", null, null))
        assertNull(format("all", null, null))
        assertNull(format("ALL", null, null))
        assertNull(format("  all  ", null, null))
    }

    @Test
    fun onlyGender_returnsGenderOnly() {
        assertEquals("Restrictions: Men only", format("male", null, null))
        assertEquals("Restrictions: Men only", format("MALE", null, null))
        assertEquals("Restrictions: Women only", format("female", null, null))
        assertEquals("Restrictions: Women only", format("Female", null, null))
    }

    @Test
    fun onlyMinAge_returnsAgeFrom() {
        assertEquals("Restrictions: Ages 18+", format(null, 18, null))
        assertEquals("Restrictions: Ages 21+", format("all", 21, null))
        assertEquals("Restrictions: Ages 16+", format("", 16, null))
    }

    @Test
    fun onlyMaxAge_returnsAgeTo() {
        assertEquals("Restrictions: Up to age 30", format(null, null, 30))
        assertEquals("Restrictions: Up to age 45", format("all", null, 45))
        assertEquals("Restrictions: Up to age 25", format("", null, 25))
    }

    @Test
    fun bothAges_returnsAgeRange() {
        assertEquals("Restrictions: Ages 18–30", format(null, 18, 30))
        assertEquals("Restrictions: Ages 20–40", format("all", 20, 40))
        assertEquals("Restrictions: Ages 25–35", format("", 25, 35))
    }

    @Test
    fun genderAndAge_returnsCombined() {
        assertEquals("Restrictions: Men only · Ages 18–30", format("male", 18, 30))
        assertEquals("Restrictions: Women only · Ages 21+", format("female", 21, null))
        assertEquals("Restrictions: Women only · Up to age 35", format("female", null, 35))
        assertEquals("Restrictions: Men only · Ages 20–50", format("MALE", 20, 50))
    }

    @Test
    fun zeroAge_treatedAsNotSet() {
        assertNull(format(null, 0, 0))
        assertNull(format(null, 0, null))
        assertNull(format(null, null, 0))
        assertNull(format("all", 0, 0))
        assertEquals("Restrictions: Men only", format("male", 0, 0))
        assertEquals("Restrictions: Ages 18+", format(null, 18, 0))
        assertEquals("Restrictions: Up to age 30", format(null, 0, 30))
        assertEquals("Restrictions: Women only · Ages 25+", format("female", 25, 0))
        assertEquals("Restrictions: Men only · Up to age 40", format("male", 0, 40))
    }
}
