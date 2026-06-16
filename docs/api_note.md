# API Build Notes

## Phase 1 — Scaffold and hello world

**Goal.** Project compiles and serves a hardcoded response on `:8080`.

### Commands (PowerShell, run from repo root)

```sh
# 1. Create the app/ folder
mkdir app
cd app

# 2. Init the Go module
go mod init gitops-vm
# go: creating new go.mod: module gitops-vm

# 3. Add gin dependency
go get github.com/gin-gonic/gin

# 4. Write VERSION (placeholder — not wired via -ldflags until Phase 3)
tee VERSION<<EOF
"0.1.0"
EOF
```

- `app/main.go`

```go
package main

import "github.com/gin-gonic/gin"

func main() {
	r := gin.Default()
	r.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"app":     "VM GitOps Practices",
			"version": "dev",
		})
	})
	r.Run(":8080")
}
```

### Verify "Done when"

Terminal A:

```sh
go run ./app
# [GIN-debug] [WARNING] Creating an Engine instance with the Logger and Recovery middleware already attached.

# [GIN-debug] [WARNING] Running in "debug" mode. Switch to "release" mode in production.
#  - using env:   export GIN_MODE=release
#  - using code:  gin.SetMode(gin.ReleaseMode)

# [GIN-debug] GET    /                         --> main.main.func1 (3 handlers)
# [GIN-debug] [WARNING] You trusted all proxies, this is NOT safe. We recommend you to set a value.
# Please check https://github.com/gin-gonic/gin/blob/master/docs/doc.md#dont-trust-all-proxies for details.
# [GIN-debug] Listening and serving HTTP on :8080
# [GIN] 2026/06/15 - 21:20:44 | 200 |       0s |             ::1 | GET      "/"
# [GIN] 2026/06/15 - 21:20:44 | 404 |  309.3µs |             ::1 | GET      "/favicon.ico"

curl http://localhost:8080/
# {"app":"VM GitOps Practices","version":"dev"}
```

Stop the server with Ctrl+C in Terminal A when done.

- Confim Files created

- `app/VERSION`
- `app/go.mod`
- `app/go.sum`
- `app/main.go`

---

## Phase 2

**Goal.** `/` and `/healthz` work; handler logic separated from server setup.

```go
// app/handlers.go
package main

import "github.com/gin-gonic/gin"

func rootHandler(c *gin.Context) {
	c.JSON(200, gin.H{
		"app":     "VM GitOps Practices",
		"version": "dev",
	})
}

func healthzHandler(c *gin.Context) {
	c.String(200, "ok")
}
```

```go
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
```

### Verify "Done when"

Terminal A:

```sh
cd app
go run .
# [GIN-debug] [WARNING] Creating an Engine instance with the Logger and Recovery middleware already attached.

# [GIN-debug] [WARNING] Running in "debug" mode. Switch to "release" mode in production.
#  - using env:   export GIN_MODE=release
#  - using code:  gin.SetMode(gin.ReleaseMode)

# [GIN-debug] GET    /                         --> main.rootHandler (3 handlers)
# [GIN-debug] GET    /healthz                  --> main.healthzHandler (3 handlers)
# [GIN-debug] [WARNING] You trusted all proxies, this is NOT safe. We recommend you to set a value.
# Please check https://github.com/gin-gonic/gin/blob/master/docs/doc.md#dont-trust-all-proxies for details.
# [GIN-debug] Listening and serving HTTP on :8080
# [GIN] 2026/06/15 - 21:33:13 | 200 |       0s |             ::1 | GET      "/"
# [GIN] 2026/06/15 - 21:33:23 | 200 |       0s |             ::1 | GET      "/healthz"
# [GIN] 2026/06/15 - 21:33:30 | 200 |       0s |             ::1 | GET      "/healthz"
```

Terminal B:

```sh
curl http://localhost:8080/
# {"app":"VM GitOps Practices","version":"dev"}

curl http://localhost:8080/healthz
# ok

curl -i http://localhost:8080/healthz
# HTTP/1.1 200 OK
# Content-Type: text/plain; charset=utf-8
# Date: Tue, 16 Jun 2026 01:33:30 GMT
# Content-Length: 2

# ok
```

- Confirm files created / changed

- `app/handlers.go`
- `app/main.go`

---
