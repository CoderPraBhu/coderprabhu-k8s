# legacy/ (not applied)

History only. Flux applies only the root `kustomization.yaml`, so nothing here reaches the cluster.

- `old-clusters/`: manifests for the deleted `allprojects-cluster` (Ingress, ManagedCertificates, in-cluster Mongo)
  and the deleted `coderprabhu-cluster`, plus the placeholder `allprojects-mongodb-atlas-secret.yaml` (real values live only in the cluster; never apply it).
- `gateway-migration/`, `migration/`, `docs/gateway-api-migration.md`: the Sep 2026 move to `allprojects-v2` + GKE
  Gateway. Paths inside them (`gateway/`, `migration/`) are as they were then.
- `README-history.md`: the old README (commands for the deleted clusters).
