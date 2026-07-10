## Migrating Azure Microservice Demo From Docker Compose To Kubernetes

Converts the docker-compose stack (2 frontends, 3 backends, 2 data) to Kubernetes
manifests generated imperatively with `kubectl create --dry-run=client -o yaml` (CKA style).


**Data** : `rabbitmq` `documentdb`

**BackEnd**: `order-service` `product-service` `makeline-service` 

**FrontEnd**: `store-front` `store-admin`

### Prerequisites:

1. make
2. kubectl

### Generated manifests
| File | Kind | Purpose |
|---|---|---|
|gen-manifests.sh|Bash Script|Generate The Yaml Files|
|helper_yaml.sh|Bash Script|Setup Vim Envinoment To Edit Yaml Without Pocking Your Eyes|
|Makefile|make|Spin Up Everything and test it and destroy it if you want|


### Usage
```bash
make gen       # runs gen-manifests.sh, produces the 7 yamls
make apply     # backends first, then services, then frontends
make test      # waits for pods ready, curls all health endpoints
make status    # pods + svc overview
make destroy   # deletes everything, keeps the yamls
```


### Verification:
```bash
root@controlplane:~$ make test
kubectl wait --for=condition=ready pod --all --timeout=180s
pod/documentdb-0 condition met
pod/makeline-service-5ffb4b88-bctvr condition met
pod/order-service-6b5db9fd7c-8b6d5 condition met
pod/product-service-5bb76766c8-p5scq condition met
pod/rabbitmq-0 condition met
pod/store-admin-86765f4c-ft7zd condition met
pod/store-front-5996d5cdc4-j4dtk condition met
kubectl run netshoot --rm -i --image=nicolaka/netshoot --restart=Never -- \
    sh -c 'echo "-- store-front --"; curl -s -o /dev/null -w "%{http_code}\n" http://store-front; \
    echo "-- store-admin --"; curl -s -o /dev/null -w "%{http_code}\n" http://store-admin; \
    echo "-- order-service --"; curl -s http://order-service:3000/health; echo; \
    echo "-- product-service --"; curl -s http://product-service:3002/health; echo; \
    echo "-- makeline-service --"; curl -s http://makeline-service:3001/health; echo'
All commands and output from this session will be recorded in container logs, including credentials and sensitive information passed through the command prompt.
If you don't see a command prompt, try pressing enter.
warning: couldn't attach to pod/netshoot, falling back to streaming logs: Internal error occurred: unable to upgrade connection: container netshoot not found in pod netshoot_default
-- store-front --
200
-- store-admin --
200
-- order-service --
{"status":"ok","version":"2.2.0"}
-- product-service --
{"status":"ok","version":"2.2.0"}
-- makeline-service --
{"status":"unavailable","version":"2.2.0"}
pod "netshoot" deleted from default namespace
```
