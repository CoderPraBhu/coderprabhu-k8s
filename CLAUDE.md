# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository holds Kubernetes manifests for deploying three production web applications on Google Kubernetes Engine (GKE):

- **coderprabhu.com** — Portfolio/personal website (UI + Spring Boot API)
- **tornacampsites.com** — Campsite booking platform
- **whatsgoodonmenu.com** — Menu discovery platform

There is no build system — all operations are `kubectl` and `gcloud` CLI commands.

## Two GKE Clusters

Files are prefixed by cluster:

| Prefix | Cluster | GCP Project |
|--------|---------|-------------|
| `coderprabhu-*` | `coderprabhu-cluster` | `kubegcp-256806` (account: `skolpe@mail.ccsf.edu`) |
| `allprojects-*` | `allprojects-cluster` | `all-projects-292200` (account: `sanskruti2489@gmail.com`) |

Switch cluster context:
```bash
# allprojects cluster
gcloud config set account sanskruti2489@gmail.com
gcloud config set project all-projects-292200
gcloud container clusters get-credentials allprojects-cluster --zone us-west1-b

# coderprabhu cluster
gcloud config set account skolpe@mail.ccsf.edu
gcloud config set project kubegcp-256806
gcloud container clusters get-credentials coderprabhu-cluster --zone us-west1-b
```

## Deploying / Updating

When a container image version changes, update the relevant deployment YAML first, then apply:

```bash
kubectl apply -f <name>-deployment.yaml
kubectl apply -f <name>-service.yaml
kubectl apply -f <prefix>-ingress.yaml
```

Key ingress uses `networking.k8s.io/v1` API (`allprojects-ingress.yaml`). The older `coderprabhu-ingress.yaml` is on the deprecated `extensions/v1beta1` API.

HTTPS redirect is enforced via FrontendConfig:
```bash
kubectl apply -f allprojects-ingress-security-config.yaml
```

## MongoDB

MongoDB runs as a StatefulSet with a `cvallance/mongo-k8s-sidecar` for replica set initialization. Version is pinned to `mongo:4.4.16` in `allprojects-mongo-statefulset.yaml`.

Deploy storage + database:
```bash
kubectl apply -f <prefix>-storage-class-hdd.yaml
kubectl apply -f <prefix>-mongo-headlessservice.yaml
kubectl apply -f <prefix>-mongo-statefulset.yaml
```

Access MongoDB shell in a pod:
```bash
kubectl exec -it mongo-0 -c mongo -- bash
# then: mongo
```

Databases: `CoderPraBhuApi`, `CampApiDB`, `MenuApi`, `campdb`

### Backup & Restore

```bash
# Backup (inside pod)
kubectl exec mongo-0 -c mongo -- mongodump --archive=/data/db/full-backup.archive --gzip

# Copy to local
kubectl cp mongo-0:/data/db/full-backup.archive ./full-backup.archive -c mongo

# Copy to target pod and restore
kubectl cp ./mongobkp mongo-0:dumpfrom
kubectl exec -it mongo-0 -c mongo -- bash
# then: mongorestore -d MenuApi /dumpfrom/mongobkp/MenuApi

# Restore to MongoDB Atlas
mongorestore --uri="mongodb+srv://UNAME:PW@cluster0.cd1r6ev.mongodb.net/" \
  --archive=./full-backup.archive --gzip
```

## Storage

StatefulSet PVCs use GCE persistent disks (pd-standard, 1Gi). **PVCs are not deleted when a StatefulSet is deleted** — manually delete with `kubectl delete pv` and `kubectl delete pvc`.

## SSL Certificates

Google-managed certificates are defined inline in the ingress YAML. List all:
```bash
gcloud beta compute ssl-certificates list --global
```

SSL policy (TLS 1.2+):
```bash
gcloud compute ssl-policies create allprojects-ingress-ssl-policy --profile MODERN --min-tls-version 1.2
```

## Node Pool Operations

To change machine type, create a new pool, cordon+drain old nodes, then delete old pool:
```bash
gcloud container node-pools create <new-pool> --cluster=<cluster> --machine-type=e2-medium --num-nodes=1
kubectl cordon <node>
kubectl drain --force --ignore-daemonsets --delete-local-data --grace-period=10 <node>
gcloud container node-pools delete <old-pool> --cluster <cluster>
```

## Useful Diagnostic Commands

```bash
kubectl get ingress
kubectl describe ingress <ingress-name>
kubectl get pods -o=wide
kubectl get statefulset
kubectl get pv && kubectl get pvc
kubectl scale deployment <name> --replicas=0   # scale down
kubectl rollout history statefulset mongo
```

## Architecture Notes

- Ingress uses GCP Global Load Balancer (not nginx ingress controller)
- Static IPs: `coderprabhu-ip` and `allprojects-ip` (global)
- MongoDB Atlas migration is in progress — `allprojects-mongodb-atlas-configmap.yaml` and `allprojects-mongodb-atlas-secret.yaml` contain placeholder credentials
- `coderprabhu-web-map-http.yaml` is a GCP URL map for HTTP→HTTPS redirect on the older cluster
