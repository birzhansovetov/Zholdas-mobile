package handler

import (
	"strings"
	"testing"
)

func TestNormalizeLegalLang(t *testing.T) {
	tests := []struct {
		input    string
		expected LegalLang
	}{
		// RU defaults
		{"ru", LangRU},
		{"RU", LangRU},
		{"  ru  ", LangRU},
		{"", LangRU},
		{"   ", LangRU},
		{"unknown", LangRU},
		{"fr", LangRU},
		{"de", LangRU},
		{"123", LangRU},

		// KK variations
		{"kk", LangKK},
		{"KK", LangKK},
		{"  kk  ", LangKK},
		{"kz", LangKK},
		{"KZ", LangKK},
		{"kaz", LangKK},
		{"qaz", LangKK},

		// EN variations
		{"en", LangEN},
		{"EN", LangEN},
		{"  en  ", LangEN},
		{"eng", LangEN},
		{"ENG", LangEN},
	}

	for _, tt := range tests {
		t.Run("input_"+tt.input, func(t *testing.T) {
			got := NormalizeLegalLang(tt.input)
			if got != tt.expected {
				t.Errorf("NormalizeLegalLang(%q) = %q; want %q", tt.input, got, tt.expected)
			}
		})
	}
}

func TestRenderLegalPage(t *testing.T) {
	languages := []LegalLang{LangRU, LangKK, LangEN}

	for _, isPrivacy := range []bool{true, false} {
		pageType := "privacy"
		if !isPrivacy {
			pageType = "terms"
		}

		for _, lang := range languages {
			t.Run(pageType+"_"+string(lang), func(t *testing.T) {
				html := renderLegalPage(isPrivacy, lang)

				// 1. Doctype first (standards mode), then the DRAFT comment
				if !strings.HasPrefix(html, "<!doctype html>") {
					t.Errorf("Page must start with <!doctype html>")
				}
				if !strings.Contains(html, "<!-- DRAFT: текст требует утверждения владельцем -->") {
					t.Errorf("Page missing mandatory draft comment")
				}

				// 2. Viewport and responsive layout constraints (720px)
				if !strings.Contains(html, "viewport") {
					t.Errorf("Page missing viewport meta tag")
				}
				if !strings.Contains(html, "max-width: 720px") {
					t.Errorf("Page missing max-width: 720px constraint")
				}

				// 3. Language switcher links present
				if !strings.Contains(html, "?lang=ru") || !strings.Contains(html, "?lang=kk") || !strings.Contains(html, "?lang=en") {
					t.Errorf("Page missing language switcher links")
				}

				// 4. Contact email placeholder
				if !strings.Contains(html, "[контактный email]") && !strings.Contains(html, "[контакттік email]") {
					t.Errorf("Page missing contact email placeholder")
				}

				// 5. Correct html lang attribute
				expectedLangAttr := `lang="` + string(lang) + `"`
				if !strings.Contains(html, expectedLangAttr) {
					t.Errorf("Page missing expected %s attribute", expectedLangAttr)
				}
			})
		}
	}
}
