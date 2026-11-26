# Domains and subdomains (allprojects-v2 Gateway)

Every site is served by one GKE Gateway (`allprojects-gateway`, `gke-l7-global-external-managed`) on the global
static IP **`allprojects-ip` = 34.98.91.174**. TLS comes from Certificate Manager: map `allprojects-cert-map`
holds one wildcard cert per apex (`<apex>` + `*.<apex>`). Routing is one HTTPRoute file per hostname/backend
in [`infra/gateway/`](../infra/gateway/).

**Routes change through a PR. Flux applies `main` after the merge.** Don't `kubectl apply` route files by hand,
because Flux reconciles them to match git.

## Add a subdomain under an existing apex (e.g. `foo.tornacampsites.com`)
1. PR: copy a single-hostname route to `infra/gateway/httproute-<apex-slug>-<function>.yaml`
   (e.g. `httproute-tornacampsites-foo.yaml`). Set `metadata.name: route-<apex-slug>-<function>`, the
   `hostnames` and the `backendRefs` Service + port, and add the file to `infra/gateway/kustomization.yaml`.
2. Merge. Check that Flux synced and the route was accepted:
   ```bash
   kubectl -n flux-system get kustomizations                       # READY True, revision = merge commit
   kubectl get httproute route-tornacampsites-foo -o yaml           # Accepted=True, ResolvedRefs=True
   ```
3. DNS console: `A  foo.tornacampsites.com -> 34.98.91.174`.
4. **No certificate work.** `*.tornacampsites.com` is already covered by `tornacampsites-wild`.

Verify: `curl -sI https://foo.tornacampsites.com/` (valid cert, expected status) and `curl -sI http://...` (301).

Template (single hostname -> single backend):
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: route-<apex-slug>-<function>
spec:
  parentRefs:
  - name: allprojects-gateway
    sectionName: https
  hostnames:
  - <fqdn>
  rules:
  - matches:
    - path: { type: PathPrefix, value: / }
    backendRefs:
    - name: <service>
      port: <port>
```
A backend whose `GET /` does not return 200 needs a HealthCheckPolicy (see `healthcheck-menu-api.yaml`).

## Remove a subdomain
PR that removes the route file (and its line in `kustomization.yaml`), merge, then delete the A record.
Flux runs with `prune: false` for now, so also delete the route by hand once:
`kubectl delete httproute route-<name>`.

## Onboard a brand-new apex domain (e.g. `newbrand.com`)
The Gateway, its IP and the `GCPGatewayPolicy` don't change. You add one wildcard cert plus two cert-map entries,
then routes. Nothing is visible to users until step 4.

1. Set the context (once per session): `gcloud config set project all-projects-292200` and
   `gcloud container clusters get-credentials allprojects-v2 --zone us-west1-b`.
2. Cert: `bash scripts/add-apex-domain.sh newbrand.com`.
   - Run 1 creates the DNS authorization and prints the `_acme-challenge.newbrand.com` CNAME. Add it in the
     domain's DNS console (Squarespace accepts the long value) and wait for `dig +short CNAME _acme-challenge.newbrand.com`.
   - Run 2 creates `newbrand-wild` (`newbrand.com,*.newbrand.com`) and the map entries `newbrand-wild-apex` and
     `newbrand-wild-wildcard`, then waits for `ACTIVE` (10-30 min). The Gateway picks them up automatically.
3. Routes: PR with `infra/gateway/httproute-newbrand-<function>.yaml` (template above, hostnames
   `newbrand.com`, `www.newbrand.com`), listed in `kustomization.yaml`. Merge and check as above.
   `httproute-redirect.yaml` (HTTP -> HTTPS) doesn't pin hostnames, so nothing to add there.
4. DNS: A records for `newbrand.com`, `www.newbrand.com` -> 34.98.91.174. Optional: `CAA 0 issue "pki.goog"`.
5. Verify:
   ```bash
   for h in newbrand.com www.newbrand.com; do
     echo "$h https=$(curl -s -o /dev/null -w '%{http_code}' https://$h/) http=$(curl -s -o /dev/null -w '%{http_code}' http://$h/)"
   done
   ```

Rollback: delete the A records, revert the route PR (and delete the route by hand while prune is off), then delete
the two map entries, the cert and the dns-authorization.

## Inspect
```bash
kubectl get gateway allprojects-gateway -o wide
kubectl get httproute
gcloud certificate-manager certificates list --format="table(name,managed.state,managed.domains)"
gcloud certificate-manager maps entries list --map=allprojects-cert-map
gcloud compute backend-services list --filter="name~gkegw1" --format="value(name)" \
  | xargs -I{} sh -c 'gcloud compute backend-services get-health {} --global --format="value(status.healthStatus[0].healthState)"'
```
SSL policy `allprojects-ingress-ssl-policy` (MODERN, TLS 1.2+) is attached by the `GCPGatewayPolicy` in
`allprojects-gateway.yaml`.
