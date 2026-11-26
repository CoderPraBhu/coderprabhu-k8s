# coderprabhu-k8s

Shared Kubernetes infra for the **`allprojects-v2`** GKE cluster (project `all-projects-292200`, zone `us-west1-b`),
which serves https://coderprabhu.com, https://tornacampsites.com (and its subdomains) and https://whatsgoodonmenu.com.

**Flux applies this repo's `main` to the cluster. Merging a PR is the deploy.** Flux checks `main` every minute
and re-applies every 10 minutes, so a manual `kubectl edit` of anything managed here is put back to match git.

## Layout

| Path | What |
|---|---|
| `kustomization.yaml` | what Flux applies: `flux-system/` + `infra/` (nothing else in the repo is applied) |
| `flux-system/` | Flux v2.10.1 (source + kustomize controllers only) and the `GitRepository`/`Kustomization` pointing at this repo |
| `infra/gateway/` | GKE Gateway + GCPGatewayPolicy, HealthCheckPolicy, one HTTPRoute per hostname/backend (all subdomains) |
| `infra/bot-access/` | read-only ServiceAccount + ClusterRole for the coderbot agent (`coderbotagent-k8s-viewer`) |
| `scripts/add-apex-domain.sh` | Certificate Manager setup for a new apex domain |
| `docs/domains-and-subdomains.md` | runbook: add/remove subdomains, onboard a new apex, inspect routing/certs |
| `DATABASE.md` | MongoDB Atlas notes |
| `legacy/` | not applied, history only: old `allprojects-cluster` and `coderprabhu-cluster` manifests (both clusters are deleted), the Sep 2026 Gateway migration scripts and doc, the old README |

## What belongs here
Only infra that spans apps. Each app's Deployment, Service and app-specific ConfigMaps are deployed by that app's
own Cloud Build (for example `camp-newapi-config` and `rentalapi-config` carry
`app.kubernetes.io/managed-by: gcp-cloud-build-deploy`). Don't add those here, or Flux and Cloud Build will fight
over them.

**No Secrets and no Atlas hostnames in git** (this repo is public). `mongodb-atlas-config` and
`mongodb-atlas-secret` live only in the cluster.

## Phase 1 settings
- `prune: false`: removing a file doesn't delete the object from the cluster yet. Delete it by hand, or turn on
  prune in `flux-system/gotk-sync.yaml` once phase 1 has run cleanly for a while.
- The repo is public, so Flux reads it anonymously (no deploy key, no token in the cluster).

## Bootstrap Flux (one time, owner, from the Mac, after this layout is on `main`)
```bash
git switch main && git pull
# 1. install Flux. The first run creates the CRDs and may print "no matches for kind GitRepository": that's expected
kubectl --context allprojects-v2 apply --server-side -k flux-system || true
kubectl --context allprojects-v2 wait --for condition=established --timeout=120s \
  crd/gitrepositories.source.toolkit.fluxcd.io crd/kustomizations.kustomize.toolkit.fluxcd.io
# 2. the second run creates the GitRepository + Kustomization. From here on, Flux manages the repo
kubectl --context allprojects-v2 apply --server-side -k flux-system
# 3. watch it sync (READY True, revision = main's HEAD)
kubectl --context allprojects-v2 -n flux-system get pods,gitrepositories,kustomizations
```
Undo: `kubectl --context allprojects-v2 delete -k flux-system`. With `prune: false` this removes only Flux; the
Gateway, routes and RBAC stay as they are.

## Check that a merge synced
```bash
kubectl -n flux-system get gitrepositories,kustomizations   # READY True; REVISION main@sha1:<merge commit>
kubectl -n flux-system describe kustomization flux-system    # errors, if any
```

## Upgrade Flux
In a PR, replace `flux-system/gotk-components.yaml` with a newer release's `install.yaml`. The patches in
`flux-system/kustomization.yaml` keep only source-controller and kustomize-controller (the single
`e2-custom-2-3072` node has little memory headroom).

## Related repos
- coderprabhu.com UI: https://github.com/CoderPraBhu/coderprabhu-ui
- coderprabhu.com API: https://github.com/CoderPraBhu/coderprabhu-api
