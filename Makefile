# AKS Store Demo -- lifecycle targets
# Usage: make gen | make apply | make test | make destroy | make status

.PHONY: gen apply test destroy status

# Generate all yamls via the imperative script
gen:
	bash gen-manifests.sh

# Apply everything in this directory
apply:
	kubectl apply -f rabbitmq.yaml
	kubectl apply -f documentdb.yaml
	kubectl apply -f order-service.yaml
	kubectl apply -f product-service.yaml
	kubectl apply -f makeline-service.yaml
	kubectl apply -f store-front.yaml
	kubectl apply -f store-admin.yaml

# Wait for pods then curl every service from a throwaway pod
test:
	kubectl wait --for=condition=ready pod --all --timeout=180s
	kubectl run netshoot --rm -i --image=nicolaka/netshoot --restart=Never -- \
		sh -c 'echo "-- store-front --"; curl -s -o /dev/null -w "%{http_code}\n" http://store-front; \
		echo "-- store-admin --"; curl -s -o /dev/null -w "%{http_code}\n" http://store-admin; \
		echo "-- order-service --"; curl -s http://order-service:3000/health; echo; \
		echo "-- product-service --"; curl -s http://product-service:3002/health; echo; \
		echo "-- makeline-service --"; curl -s http://makeline-service:3001/health; echo'

# Tear everything down (yamls stay on disk)
destroy:
	kubectl delete -f . --ignore-not-found

# Quick overview
status:
	kubectl get pods,svc -o wide
