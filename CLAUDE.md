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
| `allprojects-*` | `allprojects-v2` | `all-projects-292200` (account: `prashantbhuruk88@gmail.com`) |

`allprojects-v2` (VPC-native) replaced the routes-based `allprojects-cluster` in Sep 2026
so GKE Gateway (NEG backends) could be used. Full history: `docs/gateway-api-migration.md`.

Switch cluster context:
```bash
# allprojects cluster
gcloud config set account prashantbhuruk88@gmail.com
gcloud config set project all-projects-292200
gcloud container clusters get-credentials allprojects-v2 --zone us-west1-b

# coderprabhu cluster
gcloud config set account skolpe@mail.ccsf.edu
gcloud config set project kubegcp-256806
gcloud container clusters get-credentials coderprabhu-cluster --zone us-west1-b
```

## Deploying / Updating

**App workloads** (Deployments + Services for the 8 apps) are deployed by Cloud Build
from each app's own repo (`_GKE_CLUSTER: allprojects-v2`), except `coderprabhu-api` and
`menu-api` which are applied manually — always against the `allprojects-v2` context.
This repo does **not** hold the app Deployment/Service YAML.

**Routing (allprojects-v2):** a GKE Gateway, not an Ingress. Manifests in `gateway/`:
```bash
kubectl apply -f gateway/            # Gateway + GCPGatewayPolicy + HTTPRoutes + HealthCheckPolicy
```
- `gateway/allprojects-gateway.yaml` — Gateway (`gke-l7-global-external-managed`, static IP
  `allprojects-ip` = 34.98.91.174, cert map via `networking.gke.io/certmap`) + `GCPGatewayPolicy`
  (SSL policy `allprojects-ingress-ssl-policy`).
- `gateway/httproute-redirect.yaml` — HTTP→HTTPS 301.
- `gateway/httproute-<apex-slug>-<function>.yaml` — one per hostname/backend.
- Add a subdomain: see `docs/gateway-api-migration.md` §6. Under an existing apex it's
  just a new HTTPRoute file (the wildcard cert already covers `*.<apex>`).

`coderprabhu-cluster` still uses the old Ingress (`coderprabhu-ingress.yaml`,
`extensions/v1beta1`).

## MongoDB

**`allprojects-v2` has no in-cluster MongoDB** — the apps use MongoDB Atlas
(`mongodb-atlas-config` ConfigMap + `mongodb-atlas-secret` Secret in the `default`
namespace). The `allprojects-mongo-*.yaml` StatefulSet manifests are legacy.

The `coderprabhu-mongo-*.yaml` StatefulSet (with `cvallance/mongo-k8s-sidecar`,
`mongo:4.4.16`) still applies to `coderprabhu-cluster`.

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

`allprojects-v2` is stateless (no PVCs). On `coderprabhu-cluster`, StatefulSet PVCs use
GCE persistent disks (pd-standard, 1Gi) and **are not deleted when a StatefulSet is
deleted** — remove manually with `kubectl delete pv` / `kubectl delete pvc`.

## SSL Certificates (allprojects-v2)

Google Cloud **Certificate Manager**, not inline `ManagedCertificate` objects. One
certificate map `allprojects-cert-map` holds three **wildcard** certs
(`tornacampsites-wild`, `coderprabhu-wild`, `whatsgoodonmenu-wild` — each `<apex>` +
`*.<apex>`), attached to the Gateway via the `networking.gke.io/certmap` annotation.
Each apex has one permanent `_acme-challenge.<apex>` CNAME (DNS authorization).

```bash
gcloud certificate-manager certificates list --format="table(name,managed.state,managed.domains)"
gcloud certificate-manager maps entries list --map=allprojects-cert-map
```

New apex domain: `bash gateway/add-apex-domain.sh <apex>` (see `docs/gateway-api-migration.md` §6).

SSL policy `allprojects-ingress-ssl-policy` (MODERN / TLS 1.2+) is still used — now by the
`GCPGatewayPolicy`, not a FrontendConfig.

`coderprabhu-cluster` still uses inline `ManagedCertificate` objects in its ingress YAML.

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
# allprojects-v2 (Gateway)
kubectl get gateway allprojects-gateway -o wide
kubectl get httproute
kubectl describe gateway allprojects-gateway
gcloud compute backend-services list --filter="name~gkegw1" --format="value(name)" \
  | xargs -I{} sh -c 'gcloud compute backend-services get-health {} --global --format="value(status.healthStatus[0].healthState)"'
kubectl get pods -o wide

# coderprabhu-cluster (Ingress)
kubectl get ingress && kubectl describe ingress coderprabhu-ingress
```

## Architecture Notes

- `allprojects-v2`: VPC-native, single `e2-custom-2-3072` node, RAPID channel, GKE Gateway
  (`gke-l7-global-external-managed`) on global static IP `allprojects-ip` (34.98.91.174).
- `coderprabhu-cluster`: unchanged — routes-based, GKE Ingress + GCP Global LB, static IP
  `coderprabhu-ip`.
- Apps use MongoDB Atlas (`mongodb-atlas-*` ConfigMap/Secret); no in-cluster Mongo on v2.
- `migration/` holds the one-time scripts used for the `allprojects-cluster` → `allprojects-v2`
  rebuild. `migration/50-decommission.sh` (delete old cluster + stale certs) may still be pending.
- `coderprabhu-web-map-http.yaml` is a GCP URL map for HTTP→HTTPS redirect on `coderprabhu-cluster`.
