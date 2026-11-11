package com.example.zholdas.quality

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class MojibakeStaticTest {
    @Test
    fun `localized and primary UI sources contain no known mojibake sequences`() {
        val roots = listOf(
            File("app/src/main/java"),
            File("app/src/main/res")
        )
        val markers = listOf(
            "\u0420\u00B0", // common broken Cyrillic lowercase a
            "\u0420\u00B5", // common broken Cyrillic lowercase e
            "\u0421\u0453", // common broken Cyrillic lowercase s
            "\u0421\u201A", // common broken Cyrillic lowercase t
            "\u0420\u045F", // common broken Cyrillic uppercase P
            "\uFFFD" // Unicode replacement character
        )
        val damagedLiteral = Regex("\"[^\"\r\n]*\\?{2,}[^\"\r\n]*\"")
        val violations = roots.flatMap { root ->
            if (root.isFile) listOf(root) else root.walkTopDown()
                .filter { it.extension in listOf("kt", "xml") }.toList()
        }.filter { file ->
            val text = file.readText()
            markers.any(text::contains) || damagedLiteral.containsMatchIn(text) ||
                (file.extension == "xml" && Regex("\\?{2,}").containsMatchIn(text))
        }
        assertTrue("Mojibake found in: ${violations.joinToString { it.path }}", violations.isEmpty())
    }
}
