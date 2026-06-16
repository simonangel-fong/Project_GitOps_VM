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

### Commands (run from repo root)

```sh
# 1. Create handlers.go with both handler funcs moved out of main.go
tee app/handlers.go <<'EOF'
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
EOF

# 2. Slim main.go down to: load gin, register routes, run
tee app/main.go <<'EOF'
package main

import "github.com/gin-gonic/gin"

func main() {
	r := gin.Default()

	r.GET("/", rootHandler)
	r.GET("/healthz", healthzHandler)

	r.Run(":8080")
}
EOF
```

Notes on the `/healthz` handler:

- `c.String(200, "ok")` returns plain text with `Content-Type: text/plain; charset=utf-8`, matching PRD FR-2's `200 ok` (not JSON).
- No body wrapping, no JSON — that's intentional.

### Verify "Done when"

Terminal A:

```sh
go run ./app
# [GIN-debug] GET    /                         --> main.rootHandler (3 handlers)
# [GIN-debug] GET    /healthz                  --> main.healthzHandler (3 handlers)
# [GIN-debug] Listening and serving HTTP on :8080
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
# ...
# ok
```

Stop the server with Ctrl+C in Terminal A when done.

- Confirm files created / changed

- `app/handlers.go` (new)
- `app/main.go` (slimmed)

### Notes / adjustments

_(record anything you had to change.)_

### Next

Phase 3 — inject `version` at build time via `-ldflags`, sourced from `app/VERSION`.

---
