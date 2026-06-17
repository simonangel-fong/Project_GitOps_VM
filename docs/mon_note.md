## Golang metrics

```sh
go get github.com/prometheus/client_golang/prometheus
go get github.com/prometheus/client_golang/prometheus/promhttp
```

- Test

```sh
go test .
# ok      gitops-vm       (cached)

go run .

curl http://localhost:8080
# {"app":"VM GitOps Practices","host":"localhost","version":"dev"}
curl http://localhost:8080/healthz
# ok
curl http://localhost:8080/metrics
# # HELP gitops_api_healthy 1 if the instance reports healthy, 0 otherwise.
# # TYPE gitops_api_healthy gauge
# gitops_api_healthy{host="Simon-Laptop"} 1
# # HELP gitops_api_info Build info — always 1, labels carry version and host.
# # TYPE gitops_api_info gauge
# gitops_api_info{host="Simon-Laptop",version="dev"} 1
# # HELP gitops_api_request_duration_seconds HTTP request duration in seconds, labelled by matched route and host.
# # TYPE gitops_api_request_duration_seconds histogram
# gitops_api_request_duration_seconds_bucket{host="Simon-Laptop",path="/",le="0.005"} 1
# gitops_api_request_duration_seconds_bucket{host="Simon-Laptop",path="/",le="0.01"} 1
```

---

## Mon instance

```sh
terraform -chdir=infra output ssh_mon

terraform -chdir=infra output ssh_jump


ssh -i infra/keys/gitops-vm.pem ubuntu@<jump_public_ip> 'echo "10.0.90.20  mon" | sudo tee -a /etc/hosts'


```