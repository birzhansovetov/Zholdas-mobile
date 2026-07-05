package handler

import "testing"

func TestExtractEventAIPrompt(t *testing.T) {
	tests := []struct {
		name       string
		text       string
		wantPrompt string
		wantOK     bool
	}{
		{name: "ai prefix", text: "@ai посоветуй маршрут", wantPrompt: "посоветуй маршрут", wantOK: true},
		{name: "joryk cyrillic", text: "@Жорик что взять с собой?", wantPrompt: "что взять с собой?", wantOK: true},
		{name: "joryk latin", text: "@joryk where do we meet?", wantPrompt: "where do we meet?", wantOK: true},
		{name: "jorik latin", text: "@jorik правила встречи", wantPrompt: "правила встречи", wantOK: true},
		{name: "prefix without prompt", text: " @Жорик ", wantPrompt: "", wantOK: true},
		{name: "ordinary message", text: "привет всем", wantPrompt: "", wantOK: false},
		{name: "near prefix is ignored", text: "@airplane test", wantPrompt: "", wantOK: false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gotPrompt, gotOK := extractEventAIPrompt(tt.text)
			if gotOK != tt.wantOK {
				t.Fatalf("ok = %v, want %v", gotOK, tt.wantOK)
			}
			if gotPrompt != tt.wantPrompt {
				t.Fatalf("prompt = %q, want %q", gotPrompt, tt.wantPrompt)
			}
		})
	}
}
