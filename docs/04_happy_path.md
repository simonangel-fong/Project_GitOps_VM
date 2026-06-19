# GitOps VM: Test - Happy Path

[Back](../README.md)

- [GitOps VM: Test - Happy Path](#gitops-vm-test---happy-path)
  - [Test - Happy Path](#test---happy-path)

---

## Test - Happy Path

- stable version

```sh
# app/VERSION: replace contents
echo "0.3.0" > app/VERSION

cat app/VERSION                              # -> 0.3.0
grep -E 'version|build_healthy' deploy/release.yaml
# expect:  version: "0.3.0"
#          build_healthy: true

# Commit + push
git add app/VERSION deploy/release.yaml
git commit -m "release: 0.3.0"
git push
```
