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

## Phase 3

**Goal.** The version in `GET /` comes from `app/VERSION`, set at build time.
Default stays `"dev"` so `go run` still works without the build command.

### Files

```go
// app/main.go
package main

import "github.com/gin-gonic/gin"

var version = "dev"

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

```go
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
	c.String(200, "ok")
}
```

### Verify "Done when"

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
# [GIN] 2026/06/15 - 21:42:00 | 200 |       0s |             ::1 | GET      "/"
```

```sh
curl http://localhost:8080/
# {"app":"VM GitOps Practices","version":"dev"}
```

Ctrl+C the server.

---

**Check B — built binary picks up VERSION:**

```sh
cd app

VERSION=$(cat app/VERSION)
# build
go build -ldflags "-X main.version=${VERSION}" -o gitops-api
# go build -ldflags "-X main.version=0.1.0" -o gitops-api.exe

# run
./gitops-api
gitops-api.exe
# [GIN-debug] Listening and serving HTTP on :8080
```

```sh
curl http://localhost:8080/
# {"app":"VM GitOps Practices","version":"0.1.0"}
```

Ctrl+C the server.

- Confirm files created / changed

- `app/VERSION` (cleaned to `0.1.0` with no quotes)
- `app/main.go` (added `var version = "dev"`)
- `app/handlers.go` (reads `version` variable)
- `gitops-api` (build artifact, not committed)

---

## Phase 4

**Goal.** A `healthy=false` build returns `500 unhealthy` on `/healthz`.
Default build (`healthy=true`) returns `200 ok`. `/` is unaffected.

Notes on the design:

- `-ldflags -X` can only set string vars, so `healthy` is a **string**, not a bool.
- The flag is a _test hook_, not a feature — no debug endpoint exposes its value.
- Default is `"true"` (healthy) so the natural state needs no override; only
  the rollback-demo build sets `healthy=false`.

### Files

```go
// app/main.go
package main

import "github.com/gin-gonic/gin"

var version = "dev"
var healthy = "true"

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

```go
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
```

### Verify "Done when"

- default build: healthy

```sh
cd app
# From repo root
VERSION=$(cat app/VERSION)
go build -ldflags "-X main.version=${VERSION} -X main.healthy=true" -o gitops-api.exe
# go build -ldflags "-X main.version=0.1.0 -X main.healthy=true" -o gitops-api.exe

gitops-api.exe
```

```sh
curl -i http://localhost:8080/healthz
# HTTP/1.1 200 OK
# Content-Type: text/plain; charset=utf-8
# Date: Tue, 16 Jun 2026 02:02:06 GMT
# Content-Length: 2

# ok

curl http://localhost:8080/
# {"app":"VM GitOps Practices","version":"0.1.0"}
```

- failure build:
  - returns 500 on /healthz, / still works:\*\*

```sh
VERSION=$(cat app/VERSION)
go build -ldflags "-X main.version=${VERSION} -X main.healthy=false" -o gitops-api-bad
go build -ldflags "-X main.version=0.1.1 -X main.healthy=false" -o gitops-api-bad.exe

gitops-api-bad.exe
```

```sh
curl -i http://localhost:8080/healthz
# HTTP/1.1 500 Internal Server Error
# Content-Type: text/plain; charset=utf-8
# Content-Length: 9
#
# unhealthy

curl http://localhost:8080/
# {"app":"VM GitOps Practices","version":"0.1.1"}
```

Ctrl+C the server.

- no debug endpoint reveals the flag

```sh
curl -i http://localhost:8080/debug
# HTTP/1.1 404 Not Found

curl -i http://localhost:8080/healthy
# HTTP/1.1 404 Not Found
```

- Confirm files created / changed

- `app/main.go` (added `var healthy = "true"`)
- `app/handlers.go` (`/healthz` branches on `healthy`)
- `gitops-api` (default build, healthy)
- `gitops-api-bad` (failure-injection build, returns 500 on `/healthz`)
