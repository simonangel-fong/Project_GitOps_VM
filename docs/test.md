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

- fail version

```sh
echo "0.3.1-broken" > app/VERSION
grep -E 'version|build_healthy' deploy/release.yaml
# expect:  version: "0.3.1-broken"
#          build_healthy: false

git add .
git commit -m "demo: trigger rollback"
git push

ssh -i infra/keys/gitops-vm.pem ubuntu@16.52.182.125 "curl -s app-vm1:8080"
# {"app":"VM GitOps Practices","host":"ip-10-0-20-11","version":"0.3.1"}

ssh -i infra/keys/gitops-vm.pem ubuntu@16.52.182.125 "curl -s app-vm2:8080"
# {"app":"VM GitOps Practices","host":"ip-10-0-20-12","version":"0.3.1"}

# login jump
ssh -i infra/keys/gitops-vm.pem ubuntu@16.52.182.125 
ssh ubuntu@app-vm1 'systemctl status gitops-api'
# ● gitops-api.service - GitOps demo API (0.3.1)
#      Loaded: loaded (/etc/systemd/system/gitops-api.service; enabled; preset: enabled)
#      Active: active (running) since Wed 2026-06-17 18:46:07 UTC; 27min ago
#    Main PID: 9392 (gitops-api)
#       Tasks: 9 (limit: 1013)
#      Memory: 8.9M (peak: 9.9M)
#         CPU: 1.257s
#      CGroup: /system.slice/gitops-api.service
#              └─9392 /opt/app/current/gitops-api

# Jun 17 19:12:20 ip-10-0-20-11 gitops-api[9392]: [GIN] 2026/06/17 - 19:12:20 | 200 |   1.24ms |      10.0.90.20 | GET      "/metrics"
# Jun 17 19:12:25 ip-10-0-20-11 gitops-api[9392]: [GIN] 2026/06/17 - 19:12:25 | 200 |   1.25ms |      10.0.90.20 | GET      "/metrics"
```

- rollback

```sh
echo "0.3.1-broken" > app/VERSION
grep -E 'version|build_healthy' deploy/release.yaml
# expect:  version: "0.3.1-broken"
#          build_healthy: true

git add .
git commit -m "demo: app healthy"
git push

ssh app-vm1 'systemctl status gitops-vm'
```
