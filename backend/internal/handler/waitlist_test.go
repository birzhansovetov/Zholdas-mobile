package handler

import "testing"

func TestNormalizeWaitlistEmail(t *testing.T) {
	valid := map[string]string{
		"user@example.com":       "user@example.com",
		"  User@Example.COM  ":   "user@example.com",
		"first.last+tag@mail.kz": "first.last+tag@mail.kz",
	}
	for input, want := range valid {
		got, ok := NormalizeWaitlistEmail(input)
		if !ok || got != want {
			t.Errorf("NormalizeWaitlistEmail(%q) = %q, %v; want %q, true", input, got, ok, want)
		}
	}

	invalid := []string{"", "   ", "user", "user@", "@example.com", "user@localhost", "Name <user@example.com>", "a@b.c, d@e.f"}
	for _, input := range invalid {
		if got, ok := NormalizeWaitlistEmail(input); ok {
			t.Errorf("NormalizeWaitlistEmail(%q) = %q, true; want invalid", input, got)
		}
	}
}

func TestNormalizeWaitlistPlatform(t *testing.T) {
	cases := map[string]string{"ios": "ios", "Android": "android", "": "any", "web": "any"}
	for input, want := range cases {
		if got := normalizeWaitlistPlatform(input); got != want {
			t.Errorf("normalizeWaitlistPlatform(%q) = %q; want %q", input, got, want)
		}
	}
}
