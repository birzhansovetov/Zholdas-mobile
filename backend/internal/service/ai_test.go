package service

import (
	"context"
	"testing"
)

func TestAIService_ModerateEvent_MockRules(t *testing.T) {
	// Initialize with empty key to force mock mode
	ai := NewAIService("")
	ctx := context.Background()

	t.Run("Flag unsafe content - bomb", func(t *testing.T) {
		isUnsafe, reason, err := ai.ModerateEvent(ctx, "Making a bomb in the park", "Dangerous activity")
		if err != nil {
			t.Fatalf("Unexpected error: %v", err)
		}
		if !isUnsafe {
			t.Error("Expected event containing 'bomb' to be flagged as unsafe")
		}
		if reason == "" {
			t.Error("Expected explanation reason for block, got empty string")
		}
	})

	t.Run("Flag unsafe content - drugs", func(t *testing.T) {
		isUnsafe, _, err := ai.ModerateEvent(ctx, "Meeting for illegal drugs", "Underground exchange")
		if err != nil {
			t.Fatalf("Unexpected error: %v", err)
		}
		if !isUnsafe {
			t.Error("Expected event containing 'drugs' to be flagged as unsafe")
		}
	})

	t.Run("Pass safe content", func(t *testing.T) {
		isUnsafe, reason, err := ai.ModerateEvent(ctx, "Football match in stadium", "Let's play weekly friendly soccer match in Almaty.")
		if err != nil {
			t.Fatalf("Unexpected error: %v", err)
		}
		if isUnsafe {
			t.Errorf("Expected football event to be marked safe, but got flagged as unsafe. Reason: %s", reason)
		}
	})
}

func TestAIService_GetRecommendations_Mock(t *testing.T) {
	ai := NewAIService("")
	ctx := context.Background()

	res, err := ai.GetRecommendations(ctx, "хочу спорт", `[{"id":1,"title":"Football"}]`)
	if err != nil {
		t.Fatalf("Unexpected error: %v", err)
	}

	if res.Answer == "" {
		t.Error("Expected answer message, got empty string")
	}

	if len(res.RecommendedCardIDs) != 1 || res.RecommendedCardIDs[0] != 1 {
		t.Errorf("Expected recommended ID [1], got %v", res.RecommendedCardIDs)
	}
}
