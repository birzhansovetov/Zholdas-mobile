package handler

import (
	"fmt"
	"log"
	"net/http"
	"strings"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
)

// GetFriendshipStatus returns the status of friendship with another user
func (h *AuthHandler) GetFriendshipStatus(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	currentUserID := userIDVal.(string)

	targetUserID := c.Param("id")
	if targetUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid target user ID"})
		return
	}

	ctx := c.Request.Context()
	var initiatorID string
	var receiverID string
	var status string

	err := h.pool.QueryRow(ctx, `
		SELECT user_id, friend_id, status 
		FROM friendships 
		WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1)
	`, currentUserID, targetUserID).Scan(&initiatorID, &receiverID, &status)

	if err != nil {
		// No friendship record found
		c.JSON(http.StatusOK, gin.H{"status": "none"})
		return
	}

	if status == "accepted" {
		c.JSON(http.StatusOK, gin.H{"status": "accepted"})
		return
	}

	if status == "pending" {
		if initiatorID == currentUserID {
			c.JSON(http.StatusOK, gin.H{"status": "pending_sent"})
		} else {
			c.JSON(http.StatusOK, gin.H{"status": "pending_received"})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "none"})
}

// SendFriendRequest sends a friend request to another user
func (h *AuthHandler) SendFriendRequest(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	currentUserID := userIDVal.(string)

	targetUserID := c.Param("id")
	if targetUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid target user ID"})
		return
	}

	if currentUserID == targetUserID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot send friend request to yourself"})
		return
	}

	ctx := c.Request.Context()

	// Verify target user exists
	var existsUser bool
	err := h.pool.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM profiles WHERE user_id = $1)", targetUserID).Scan(&existsUser)
	if err != nil || !existsUser {
		c.JSON(http.StatusNotFound, gin.H{"error": "Target user not found"})
		return
	}

	// Check if either blocker/blocked exists between the two users
	var isBlocked bool
	err = h.pool.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM blocks 
			WHERE (blocker_id = $1 AND blocked_id = $2) 
			   OR (blocker_id = $2 AND blocked_id = $1)
		)
	`, currentUserID, targetUserID).Scan(&isBlocked)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database check failed"})
		return
	}
	if isBlocked {
		c.JSON(http.StatusForbidden, gin.H{"error": "Cannot send friend request: blocker relationship exists"})
		return
	}

	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	var initiatorID string
	var receiverID string
	var status string

	err = tx.QueryRow(ctx, `
		SELECT user_id, friend_id, status 
		FROM friendships 
		WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1)
	`, currentUserID, targetUserID).Scan(&initiatorID, &receiverID, &status)

	if err == nil {
		// A relationship already exists
		if status == "accepted" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Already friends"})
			return
		}
		if status == "pending" {
			if initiatorID == currentUserID {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Friend request already sent"})
				return
			} else {
				// The other user sent a request to us, so we automatically accept it
				_, err = tx.Exec(ctx, `
					UPDATE friendships
					SET status = 'accepted'
					WHERE user_id = $1 AND friend_id = $2
				`, initiatorID, receiverID)
				if err != nil {
					c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to accept existing request"})
					return
				}

				// Fetch current user full name
				var actorName string
				_ = tx.QueryRow(ctx, "SELECT full_name FROM profiles WHERE user_id = $1", currentUserID).Scan(&actorName)
				if actorName == "" {
					actorName = "Пользователь"
				}

				// Insert notification for accepting
				_, _ = tx.Exec(ctx, `
					INSERT INTO notifications (user_id, actor_id, notification_type, text)
					VALUES ($1, $2, 'friend_accept', $3)
				`, targetUserID, currentUserID, fmt.Sprintf("%s принял ваш запрос в друзья", actorName))

				if err := tx.Commit(ctx); err != nil {
					c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
					return
				}

				c.JSON(http.StatusOK, gin.H{"message": "Friend request accepted automatically", "status": "accepted"})
				return
			}
		}
	}

	// No relationship exists, insert new pending request
	_, err = tx.Exec(ctx, `
		INSERT INTO friendships (user_id, friend_id, status)
		VALUES ($1, $2, 'pending')
	`, currentUserID, targetUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send friend request: " + err.Error()})
		return
	}

	// Get actor full name
	var actorName string
	_ = tx.QueryRow(ctx, "SELECT full_name FROM profiles WHERE user_id = $1", currentUserID).Scan(&actorName)
	if actorName == "" {
		actorName = "Пользователь"
	}

	// Create notification for the target user
	_, err = tx.Exec(ctx, `
		INSERT INTO notifications (user_id, actor_id, notification_type, text)
		VALUES ($1, $2, 'friend_request', $3)
	`, targetUserID, currentUserID, fmt.Sprintf("%s отправил вам запрос в друзья", actorName))
	if err != nil {
		log.Printf("[Warning] Failed to create notification for friend request: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "Friend request sent successfully", "status": "pending_sent"})
}

// AcceptFriendRequest accepts a pending friend request
func (h *AuthHandler) AcceptFriendRequest(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	currentUserID := userIDVal.(string)

	targetUserID := c.Param("id")
	if targetUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid target user ID"})
		return
	}

	ctx := c.Request.Context()

	tx, err := h.pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
		return
	}
	defer tx.Rollback(ctx)

	// Check if there is a pending request from target user to current user
	var status string
	err = tx.QueryRow(ctx, `
		SELECT status FROM friendships
		WHERE user_id = $1 AND friend_id = $2
	`, targetUserID, currentUserID).Scan(&status)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "No pending friend request found from this user"})
		return
	}

	if status == "accepted" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Already friends"})
		return
	}

	// Update status
	_, err = tx.Exec(ctx, `
		UPDATE friendships
		SET status = 'accepted'
		WHERE user_id = $1 AND friend_id = $2
	`, targetUserID, currentUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to accept friend request"})
		return
	}

	// Get actor full name
	var actorName string
	_ = tx.QueryRow(ctx, "SELECT full_name FROM profiles WHERE user_id = $1", currentUserID).Scan(&actorName)
	if actorName == "" {
		actorName = "Пользователь"
	}

	// Notify the sender
	_, err = tx.Exec(ctx, `
		INSERT INTO notifications (user_id, actor_id, notification_type, text)
		VALUES ($1, $2, 'friend_accept', $3)
	`, targetUserID, currentUserID, fmt.Sprintf("%s принял ваш запрос в друзья", actorName))
	if err != nil {
		log.Printf("[Warning] Failed to create notification for friend accept: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit transaction"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Friend request accepted successfully"})
}

// RejectFriendRequest rejects a request or removes a friend
func (h *AuthHandler) RejectFriendRequest(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	currentUserID := userIDVal.(string)

	targetUserID := c.Param("id")
	if targetUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid target user ID"})
		return
	}

	ctx := c.Request.Context()

	res, err := h.pool.Exec(ctx, `
		DELETE FROM friendships
		WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1)
	`, currentUserID, targetUserID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove friendship: " + err.Error()})
		return
	}

	if res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "No friendship or request found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Friendship or request successfully removed"})
}

// GetFriends returns all accepted friends of the user
func (h *AuthHandler) GetFriends(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	currentUserID := userIDVal.(string)

	ctx := c.Request.Context()

	rows, err := h.pool.Query(ctx, `
		SELECT p.user_id::text, COALESCE(au.email, ''), p.username, p.full_name, p.avatar_url, p.bio, p.city
		FROM friendships f
		JOIN profiles p ON (p.user_id = f.user_id AND f.friend_id = $1) OR (p.user_id = f.friend_id AND f.user_id = $1)
		LEFT JOIN auth.users au ON au.id = p.user_id
		WHERE f.status = 'accepted' AND p.user_id != $1
	`, currentUserID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to query friends: " + err.Error()})
		return
	}
	defer rows.Close()

	friends := []gin.H{}
	for rows.Next() {
		var id string
		var email, username, fullName string
		var avatarURL, bio, city *string

		err = rows.Scan(&id, &email, &username, &fullName, &avatarURL, &bio, &city)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan friend profile"})
			return
		}

		friendItem := gin.H{
			"id":        id,
			"email":     email,
			"username":  username,
			"full_name": fullName,
		}

		if avatarURL != nil {
			friendItem["avatar_url"] = *avatarURL
		} else {
			friendItem["avatar_url"] = ""
		}

		if bio != nil {
			friendItem["bio"] = *bio
		} else {
			friendItem["bio"] = ""
		}

		if city != nil {
			friendItem["city"] = *city
		} else {
			friendItem["city"] = ""
		}

		friends = append(friends, friendItem)
	}

	c.JSON(http.StatusOK, friends)
}

// GetFriendRequests returns all pending incoming friend requests
func (h *AuthHandler) GetFriendRequests(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	currentUserID := userIDVal.(string)

	ctx := c.Request.Context()

	rows, err := h.pool.Query(ctx, `
		SELECT p.user_id::text, COALESCE(au.email, ''), p.username, p.full_name, p.avatar_url, p.bio, p.city
		FROM friendships f
		JOIN profiles p ON p.user_id = f.user_id
		LEFT JOIN auth.users au ON au.id = p.user_id
		WHERE f.friend_id = $1 AND f.status = 'pending'
	`, currentUserID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to query friend requests: " + err.Error()})
		return
	}
	defer rows.Close()

	requests := []gin.H{}
	for rows.Next() {
		var id string
		var email, username, fullName string
		var avatarURL, bio, city *string

		err = rows.Scan(&id, &email, &username, &fullName, &avatarURL, &bio, &city)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan requester profile"})
			return
		}

		requestItem := gin.H{
			"id":        id,
			"email":     email,
			"username":  username,
			"full_name": fullName,
		}

		if avatarURL != nil {
			requestItem["avatar_url"] = *avatarURL
		} else {
			requestItem["avatar_url"] = ""
		}

		if bio != nil {
			requestItem["bio"] = *bio
		} else {
			requestItem["bio"] = ""
		}

		if city != nil {
			requestItem["city"] = *city
		} else {
			requestItem["city"] = ""
		}

		requests = append(requests, requestItem)
	}

	c.JSON(http.StatusOK, requests)
}

// UserSearchResult represents a user profile returned by user search
type UserSearchResult struct {
	ID               string `json:"id"`
	Username         string `json:"username"`
	FullName         string `json:"full_name"`
	AvatarURL        string `json:"avatar_url"`
	City             string `json:"city"`
	FriendshipStatus string `json:"friendship_status"`
}

// SearchUsers searches users to add as friends
func (h *AuthHandler) SearchUsers(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	currentUserID := userIDVal.(string)

	q := strings.TrimSpace(c.Query("q"))
	if utf8.RuneCountInString(q) < 2 {
		c.JSON(http.StatusOK, []UserSearchResult{})
		return
	}

	escapedQ := strings.ReplaceAll(q, `\`, `\\`)
	escapedQ = strings.ReplaceAll(escapedQ, `%`, `\%`)
	escapedQ = strings.ReplaceAll(escapedQ, `_`, `\_`)
	searchPattern := "%" + escapedQ + "%"

	ctx := c.Request.Context()
	rows, err := h.pool.Query(ctx, `
		SELECT
			p.user_id::text,
			COALESCE(p.username, ''),
			COALESCE(p.full_name, ''),
			COALESCE(p.avatar_url, ''),
			COALESCE(p.city, ''),
			CASE
				WHEN f.status = 'accepted' THEN 'accepted'
				WHEN f.status = 'pending' AND f.user_id = $1 THEN 'pending_sent'
				WHEN f.status = 'pending' AND f.friend_id = $1 THEN 'pending_received'
				ELSE 'none'
			END AS friendship_status
		FROM profiles p
		LEFT JOIN friendships f ON
			(f.user_id = $1 AND f.friend_id = p.user_id)
			OR (f.user_id = p.user_id AND f.friend_id = $1)
		WHERE p.user_id != $1
		  AND COALESCE(p.is_banned, false) = false
		  AND (
			  p.username ILIKE $2 ESCAPE '\'
			  OR p.full_name ILIKE $2 ESCAPE '\'
		  )
		  AND NOT EXISTS (
			  SELECT 1 FROM blocks b
			  WHERE (b.blocker_id = $1 AND b.blocked_id = p.user_id)
			     OR (b.blocker_id = p.user_id AND b.blocked_id = $1)
		  )
		ORDER BY p.full_name ASC
		LIMIT 20
	`, currentUserID, searchPattern)
	if err != nil {
		log.Printf("[Error] Failed to search users: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to search users"})
		return
	}
	defer rows.Close()

	users := make([]UserSearchResult, 0)
	for rows.Next() {
		var u UserSearchResult
		if err := rows.Scan(&u.ID, &u.Username, &u.FullName, &u.AvatarURL, &u.City, &u.FriendshipStatus); err != nil {
			log.Printf("[Error] Failed to scan searched user: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to search users"})
			return
		}
		users = append(users, u)
	}

	if err := rows.Err(); err != nil {
		log.Printf("[Error] Error iterating searched users: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to search users"})
		return
	}

	c.JSON(http.StatusOK, users)
}
