// app/handlers.go
package main

import "github.com/gin-gonic/gin"

// GET /
func rootHandler(c *gin.Context) {
	c.JSON(200, gin.H{
		"app":     "VM GitOps Practices",
		"version": "dev",
	})
}

// GET healthz/
func healthzHandler(c *gin.Context) {
	c.String(200, "ok")
}
