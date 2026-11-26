# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Shared Kubernetes infra for the **`allprojects-v2`** GKE cluster (project `all-projects-292200`, zone `us-west1-b`),
which serves three production sites:

- **coderprabhu.com**: portfolio/personal website (UI + Spring Boot API)
- **tornacampsites.com** (+ subdomains): campsite booking and rental sites
- **whatsgoodonmenu.com**: menu discovery platform

It is the only cluster. `allprojects-cluster` and `coderprabhu-cluster` are deleted; their manifests are in `legacy/`.

## GitOps: Flux applies `main`

- Flux (in `flux-system/`) applies the repo root `kustomization.yaml` (= `flux-system/` + `infra/`) from `main`.
  **Merging a PR is the deploy.** Never `kubectl apply`/`edit` managed objects by hand; Flux reverts drift.
- Check a merge synced: `kubectl -n flux-system get gitrepositories,kustomizations` (READY True, revision = merge commit).
- `prune: false` (phase 1): removing a file doesn't delete the object. Say so in the PR and give the
  `kubectl delete` the owner must run.
- Nothing under `legacy/` is applied. Don't add files there to "deploy" them, and don't apply them.

## What belongs here

Only infra that spans apps: the Gateway and HTTPRoutes (`infra/gateway/`), and the read-only RBAC for the
coderbot agent (`infra/bot-access/`). New shared infra goes in a new `infra/<name>/` folder listed in
`infra/kustomization.yaml`.

**Not here:**
- App Deployments, Services and app-specific ConfigMaps. Each app's own repo deploys those through Cloud Build
  (`_GKE_CLUSTER: allprojects-v2`). `coderprabhu-api` and `menu-api` are applied manually from their repos.
  `camp-newapi-config` and `rentalapi-config` are labeled `app.kubernetes.io/managed-by: gcp-cloud-build-deploy`.
- **Secrets, credentials and the MongoDB Atlas host.** The repo is public. `mongodb-atlas-config` and
  `mongodb-atlas-secret` live only in the cluster (`legacy/old-clusters/` holds placeholder templates).

## Routing and certificates

- One GKE Gateway `allprojects-gateway` (`gke-l7-global-external-managed`) on global static IP
  **`allprojects-ip` = 34.98.91.174**. It references cert map `allprojects-cert-map` (via `networking.gke.io/certmap`)
  and SSL policy `allprojects-ingress-ssl-policy` (via `GCPGatewayPolicy`, same file).
- `infra/gateway/httproute-redirect.yaml`: HTTP -> HTTPS 301, hostname-agnostic.
- `infra/gateway/httproute-<apex-slug>-<function>.yaml`: one per hostname/backend. Every file must be listed in
  `infra/gateway/kustomization.yaml` (which sets `namespace: default`).
- Certificate Manager wildcard certs `tornacampsites-wild`, `coderprabhu-wild`, `whatsgoodonmenu-wild`
  (`<apex>` + `*.<apex>`). A new subdomain under an existing apex needs no cert work.
- Runbook (add/remove subdomain, new apex via `scripts/add-apex-domain.sh`, inspect):
  `docs/domains-and-subdomains.md`.

## MongoDB

No in-cluster MongoDB. The apps use MongoDB Atlas through the `mongodb-atlas-config` ConfigMap and the
`mongodb-atlas-secret` Secret in `default`. Databases: `CoderPraBhuApi`, `CampApiDB`, `MenuApi`, `campdb`.
See `DATABASE.md`. Never commit Atlas credentials, the Atlas host or backup archives.

## Cluster facts

- VPC-native, single `e2-custom-2-3072` node (~85% memory requested), RAPID channel. Keep new controllers small.
- Stateless (no PVCs).
- Node pool change: create a new pool, cordon and drain the old nodes, delete the old pool.

## Useful commands

```bash
gcloud container clusters get-credentials allprojects-v2 --zone us-west1-b --project all-projects-292200
kubectl kustomize .                      # render exactly what Flux applies
kubectl diff -k infra                    # compare the repo with the live cluster (read-only)
kubectl get gateway allprojects-gateway -o wide && kubectl get httproute
kubectl -n flux-system get pods,gitrepositories,kustomizations
```
