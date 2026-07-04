package handler

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/gin-gonic/gin"
)

// UploadImage handles uploading profile avatars or event images
func (h *AuthHandler) UploadImage(c *gin.Context) {
	// 1. Get file from multipart request
	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file received: " + err.Error()})
		return
	}

	// 2. Validate file extension
	ext := strings.ToLower(filepath.Ext(file.Filename))
	if ext != ".jpg" && ext != ".jpeg" && ext != ".png" && ext != ".webp" && ext != ".heic" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Unsupported file format. Only JPG, PNG, WEBP, and HEIC are allowed."})
		return
	}

	// 3. Generate unique filename
	randomBytes := make([]byte, 16)
	_, _ = rand.Read(randomBytes)
	uniqueName := fmt.Sprintf("%s%s", hex.EncodeToString(randomBytes), ext)

	// 4. Save file to static folder
	dst := filepath.Join("uploads", uniqueName)
	if err := c.SaveUploadedFile(file, dst); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save file: " + err.Error()})
		return
	}

	// 5. Return relative URL path
	c.JSON(http.StatusOK, gin.H{
		"url": "/uploads/" + uniqueName,
	})
}
