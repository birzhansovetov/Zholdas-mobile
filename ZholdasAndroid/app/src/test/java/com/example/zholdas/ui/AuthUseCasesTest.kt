package com.example.zholdas.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AuthUseCasesTest {

    @Test
    fun testSignInValidation_validCredentials() {
        val result = AuthUseCases.validateSignIn("user@zholdas.kz", "password123")
        assertTrue("Expected valid sign in credentials", result.isValid)
        assertEquals(null, result.errorMessage)
    }

    @Test
    fun testSignInValidation_emptyEmail() {
        val result = AuthUseCases.validateSignIn("   ", "password123")
        assertFalse(result.isValid)
        assertEquals("Email не может быть пустым", result.errorMessage)
    }

    @Test
    fun testSignInValidation_invalidEmailFormat() {
        val result = AuthUseCases.validateSignIn("invalidemail", "password123")
        assertFalse(result.isValid)
        assertEquals("Некорректный формат email", result.errorMessage)
    }

    @Test
    fun testSignInValidation_emptyPassword() {
        val result = AuthUseCases.validateSignIn("user@zholdas.kz", "")
        assertFalse(result.isValid)
        assertEquals("Пароль не может быть пустым", result.errorMessage)
    }

    @Test
    fun testSignUpValidation_validInput() {
        val result = AuthUseCases.validateSignUp(
            email = "dana@zholdas.kz",
            password = "securePassword",
            confirmPassword = "securePassword",
            fullName = "Дана Алиева"
        )
        assertTrue(result.isValid)
    }

    @Test
    fun testSignUpValidation_passwordMismatch() {
        val result = AuthUseCases.validateSignUp(
            email = "dana@zholdas.kz",
            password = "password123",
            confirmPassword = "password321",
            fullName = "Дана Алиева"
        )
        assertFalse(result.isValid)
        assertEquals("Пароли не совпадают", result.errorMessage)
    }

    @Test
    fun testSignUpValidation_shortPassword() {
        val result = AuthUseCases.validateSignUp(
            email = "dana@zholdas.kz",
            password = "12345",
            confirmPassword = "12345",
            fullName = "Дана Алиева"
        )
        assertFalse(result.isValid)
        assertEquals("Пароль должен содержать минимум 6 символов", result.errorMessage)
    }

    @Test
    fun testSignUpValidation_emptyFullName() {
        val result = AuthUseCases.validateSignUp(
            email = "dana@zholdas.kz",
            password = "password123",
            confirmPassword = "password123",
            fullName = "   "
        )
        assertFalse(result.isValid)
        assertEquals("Имя не может быть пустым", result.errorMessage)
    }

    @Test
    fun testGenderAndAgeSelection_validSelection() {
        val maleResult = AuthUseCases.validateGenderAndAge("Мужской", 25)
        assertTrue(maleResult.isValid)

        val femaleResult = AuthUseCases.validateGenderAndAge("Женский", 18)
        assertTrue(femaleResult.isValid)

        val unspecifiedResult = AuthUseCases.validateGenderAndAge("Не указывать", 30)
        assertTrue(unspecifiedResult.isValid)
    }

    @Test
    fun testGenderAndAgeSelection_underageUser() {
        val result = AuthUseCases.validateGenderAndAge("Мужской", 14)
        assertFalse(result.isValid)
        assertEquals("Возраст должен быть не менее 16 лет", result.errorMessage)
    }

    @Test
    fun testGenderAndAgeSelection_invalidGender() {
        val result = AuthUseCases.validateGenderAndAge("Неизвестно", 22)
        assertFalse(result.isValid)
        assertEquals("Некорректный пол", result.errorMessage)
    }

    @Test
    fun testBioMetadataFormattingAndParsing() {
        val formatted = AuthUseCases.formatBioWithMetadata("Женский", 2001, "Люблю горы и кофе")
        assertEquals("[gender:Женский][birth_year:2001]Люблю горы и кофе", formatted)

        val parsed = AuthUseCases.parseBioMetadata(formatted)
        assertEquals("Женский", parsed.gender)
        assertEquals(2001, parsed.birthYear)
        assertEquals("Люблю горы и кофе", parsed.bioText)
    }

    @Test
    fun testExtractUsernameFromEmail() {
        val username = AuthUseCases.extractUsernameFromEmail("arman.zholdas@mail.kz")
        assertEquals("arman.zholdas", username)
    }
}
