// app/handlers.go
package main

import "github.com/gin-gonic/gin"

func rootHandler(c *gin.Context) {
	c.JSON(200, gin.H{
		"app":     "VM GitOps Practices",
		"version": version,
	})
}

func healthzHandler(c *gin.Context) {
	if healthy != "true" {
		c.String(500, "unhealthy")
		return
	}
	c.String(200, "ok")
}
