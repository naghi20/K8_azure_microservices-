#!/usr/bin/env bash
# Generate all AKS Store Demo manifests imperatively (CKA-style).
# Pattern per component: deployment -> env -> resources -> "---" -> service -> post-edits
set -euo pipefail

# ----------------------------------------------------------------
# rabbitmq (StatefulSet + ClusterIP)
# ----------------------------------------------------------------
kubectl create deployment rabbitmq \
  --image=rabbitmq:4.3.2-management-alpine \
  --port=5672 \
  --replicas=1 \
  --dry-run=client -o yaml > rabbitmq.yaml

kubectl set env -f rabbitmq.yaml --local -o yaml \
  RABBITMQ_DEFAULT_USER=username \
  RABBITMQ_DEFAULT_PASS=password > tmp && mv tmp rabbitmq.yaml

kubectl set resources -f rabbitmq.yaml --local -o yaml \
  --requests=cpu=10m,memory=128Mi \
  --limits=cpu=250m,memory=256Mi > tmp && mv tmp rabbitmq.yaml

echo "---" >> rabbitmq.yaml

kubectl create service clusterip rabbitmq \
  --tcp=5672:5672 \
  --tcp=15672:15672 \
  --dry-run=client -o yaml >> rabbitmq.yaml

# Deployment -> StatefulSet (strategy: {} is a single line in generator output)
sed -i 's/Deployment/StatefulSet/g' rabbitmq.yaml
sed -i '/strategy:/d' rabbitmq.yaml

# ----------------------------------------------------------------
# documentdb (StatefulSet + ClusterIP, needs enableServiceLinks: false)
# ----------------------------------------------------------------
kubectl create deployment documentdb \
  --image=ghcr.io/documentdb/documentdb/documentdb-local:pg17-0.112.0 \
  --port=10260 \
  --replicas=1 \
  --dry-run=client -o yaml > documentdb.yaml

# Fix: service-link env vars (DOCUMENTDB_PORT=tcp://...) break the entrypoint
# https://kubernetes.io/docs/tutorials/services/connect-applications-service/#accessing-the-service
kubectl patch -f documentdb.yaml --local --type merge \
  -p '{"spec":{"template":{"spec":{"enableServiceLinks":false}}}}' \
  -o yaml > tmp && mv tmp documentdb.yaml

echo "---" >> documentdb.yaml

kubectl create service clusterip documentdb \
  --tcp=10260:10260 \
  --dry-run=client -o yaml >> documentdb.yaml

sed -i 's/Deployment/StatefulSet/g' documentdb.yaml
sed -i '/strategy:/d' documentdb.yaml

# ----------------------------------------------------------------
# order-service (Deployment + ClusterIP)
# ----------------------------------------------------------------
kubectl create deployment order-service \
  --image=ghcr.io/azure-samples/aks-store-demo/order-service:2.2.0 \
  --port=3000 \
  --replicas=1 \
  --dry-run=client -o yaml > order-service.yaml

kubectl set env -f order-service.yaml --local -o yaml \
  ORDER_QUEUE_HOSTNAME=rabbitmq \
  ORDER_QUEUE_PORT=5672 \
  ORDER_QUEUE_USERNAME=username \
  ORDER_QUEUE_PASSWORD=password \
  ORDER_QUEUE_NAME=orders > tmp && mv tmp order-service.yaml

echo "---" >> order-service.yaml

kubectl create service clusterip order-service \
  --tcp=3000:3000 \
  --dry-run=client -o yaml >> order-service.yaml

# ----------------------------------------------------------------
# product-service (Deployment + ClusterIP)
# ----------------------------------------------------------------
kubectl create deployment product-service \
  --image=ghcr.io/azure-samples/aks-store-demo/product-service:2.2.0 \
  --port=3002 \
  --replicas=1 \
  --dry-run=client -o yaml > product-service.yaml

kubectl set env -f product-service.yaml --local -o yaml \
  AI_SERVICE_URL=http://ai-service:5001/ > tmp && mv tmp product-service.yaml

echo "---" >> product-service.yaml

kubectl create service clusterip product-service \
  --tcp=3002:3002 \
  --dry-run=client -o yaml >> product-service.yaml

# ----------------------------------------------------------------
# makeline-service (Deployment + ClusterIP)
# NOTE: quote the DB URI -- '&' breaks unquoted shell args
# ----------------------------------------------------------------
kubectl create deployment makeline-service \
  --image=ghcr.io/azure-samples/aks-store-demo/makeline-service:2.2.0 \
  --port=3001 \
  --replicas=1 \
  --dry-run=client -o yaml > makeline-service.yaml

kubectl set env -f makeline-service.yaml --local -o yaml \
  ORDER_QUEUE_URI=amqp://rabbitmq:5672 \
  ORDER_QUEUE_USERNAME=username \
  ORDER_QUEUE_PASSWORD=password \
  ORDER_QUEUE_NAME=orders \
  'ORDER_DB_URI=mongodb://documentdb:10260/?tls=true&tlsAllowInvalidCertificates=true' \
  ORDER_DB_NAME=orderdb \
  ORDER_DB_COLLECTION_NAME=orders \
  ORDER_DB_USERNAME=username \
  ORDER_DB_PASSWORD=password > tmp && mv tmp makeline-service.yaml

echo "---" >> makeline-service.yaml

kubectl create service clusterip makeline-service \
  --tcp=3001:3001 \
  --dry-run=client -o yaml >> makeline-service.yaml

# ----------------------------------------------------------------
# store-front (Deployment + LoadBalancer 80 -> 8080)
# ----------------------------------------------------------------
kubectl create deployment store-front \
  --image=ghcr.io/azure-samples/aks-store-demo/store-front:2.2.0 \
  --port=8080 \
  --replicas=1 \
  --dry-run=client -o yaml > store-front.yaml

echo "---" >> store-front.yaml

kubectl create service loadbalancer store-front \
  --tcp=80:8080 \
  --dry-run=client -o yaml >> store-front.yaml

# ----------------------------------------------------------------
# store-admin (Deployment + LoadBalancer 80 -> 8081)
# ----------------------------------------------------------------
kubectl create deployment store-admin \
  --image=ghcr.io/azure-samples/aks-store-demo/store-admin:2.2.0 \
  --port=8081 \
  --replicas=1 \
  --dry-run=client -o yaml > store-admin.yaml

echo "---" >> store-admin.yaml

kubectl create service loadbalancer store-admin \
  --tcp=80:8081 \
  --dry-run=client -o yaml >> store-admin.yaml

echo "Done. Generated: rabbitmq documentdb order-service product-service makeline-service store-front store-admin"
