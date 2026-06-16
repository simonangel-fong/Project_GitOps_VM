// app/main.go
package main

import "github.com/gin-gonic/gin"

func main() {
	r := gin.Default()

	// GET /
	r.GET("/", rootHandler)

	// GET /healthz
	r.GET("/healthz", healthzHandler)

	// port
	r.Run(":8080")
}
