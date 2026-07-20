package com.example.zholdas.quality

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class MojibakeStaticTest {
    @Test
    fun `localized and primary UI sources contain no known mojibake sequences`() {
        val roots = listOf(
            File("app/src/main/java/com/example/zholdas/data/local/Localization.kt"),
            File("app/src/main/java/com/example/zholdas/ui/screens/chats"),
            File("app/src/main/java/com/example/zholdas/ui/screens/map")
        )
        val markers = listOf(
            "\u0420\u00B0", // common broken Cyrillic lowercase a
            "\u0420\u00B5", // common broken Cyrillic lowercase e
            "\u0421\u0453", // common broken Cyrillic lowercase s
            "\u0421\u201A", // common broken Cyrillic lowercase t
            "\u0420\u045F"  // common broken Cyrillic uppercase P
        )
        val violations = roots.flatMap { root ->
            if (root.isFile) listOf(root) else root.walkTopDown().filter { it.extension == "kt" }.toList()
        }.filter { file -> markers.any(file.readText()::contains) }
        assertTrue("Mojibake found in: ${violations.joinToString { it.path }}", violations.isEmpty())
    }
}
