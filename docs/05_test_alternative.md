# GitOps VM: Test - Alternative Path

[Back](../README.md)

- [GitOps VM: Test - Alternative Path](#gitops-vm-test---alternative-path)
  - [Test - Alternative Path](#test---alternative-path)

---

## Test - Alternative Path

- buggy version

```sh
# app/VERSION: replace contents
echo "0.3.2" > app/VERSION

cat app/VERSION                              # -> 0.3.2
grep -E 'version|build_healthy' deploy/release.yaml
# expect:  version: "0.3.2"
#          build_healthy: false

# Commit + push
git add .
git commit -m "release: 0.3.2"
git push
```

![happy01](./pic/test_happy01.png)

![happy02](./pic/test_happy02.png)
