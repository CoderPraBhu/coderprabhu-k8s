# allprojects-cluster: Ingress → Gateway API + Certificate Manager migration

**Status:** In progress — started 2026-09-06
**Scope:** `allprojects-cluster` only (`all-projects-292200`). The `coderprabhu-cluster` is not touched.
**Owner account:** `prashantbhuruk88@gmail.com` (has `roles/owner` on `all-projects-292200`)

---

## 1. Why we are doing this

### The problem

`allprojects-ingress.yaml` routes 16 hostnames, each with its own Google-managed
`ManagedCertificate`. The GCP external Application Load Balancer's target HTTPS proxy
**can reference at most 15 SSL certificate resources**. Adding the 16th
(`gym.tornacampsites.com`) made the ingress controller fail every sync:

```
Error 400: At most 15 SSL certificate(s) (16 in the request) can be specified
for setting SSL certificates in TargetHttpsProxy
```

`gym.tornacampsites.com` (and `new.tornacampsites.com`) have been stuck
`Provisioning` / `FailedNotVisible` ever since — their certs can never attach to the
load balancer, so Google's CA can never validate them.

### Options considered

| Option | Verdict |
|---|---|
| **Consolidate** domains into multi-SAN `ManagedCertificate` objects (≤100 domains each) | Works, low risk, but stays capped at 15 certs total, `spec.domains` is immutable (every new subdomain = delete + recreate the whole cert = all its domains re-provision), and provisioning is all-or-nothing. Bad fit for a repo that adds subdomains often. |
| **Certificate Manager on the existing Ingress** | **Not possible.** GKE Ingress does not support Certificate Manager. Confirmed in GKE docs: *"GKE Ingress does not support certificates managed by Certificate Manager. To use certificates managed by Certificate Manager, use the Gateway API."* The `networking.gke.io/certmap` annotation is silently ignored on an Ingress. |
| **Config Connector** (manage certs as CRDs) | Requires enabling Workload Identity (recreates the single node = full cluster downtime), enabling the addon (~0.5–1 GB memory on a node already at ~74%), and a bigger machine type (ongoing cost). Too much machinery for the payoff. |
| **Gateway API + Certificate Manager** ← chosen | Removes the cert limit entirely (a certificate *map* attaches to the proxy as one object holding many entries). Gateway API is GA and is the API that receives new features; Ingress is frozen. Cost is a one-time migration project. |

### Decision

Migrate `allprojects-ingress` to a **GKE Gateway** (`gke-l7-global-external-managed`
GatewayClass — global external Application Load Balancer, the same LB type the Ingress
uses today) with **HTTPRoute** resources for routing, and terminate TLS with a
**Certificate Manager certificate map** referenced via the
`networking.gke.io/certmap` annotation.

Use **three wildcard certificates** (one per apex domain), not per-hostname certs:

| Certificate | SAN domains | DNS authorization on |
|---|---|---|
| `tornacampsites-wild` | `tornacampsites.com`, `*.tornacampsites.com` | `tornacampsites.com` |
| `coderprabhu-wild` | `coderprabhu.com`, `*.coderprabhu.com` | `coderprabhu.com` |
| `whatsgoodonmenu-wild` | `whatsgoodonmenu.com`, `*.whatsgoodonmenu.com` | `whatsgoodonmenu.com` |

A DNS authorization for `example.com` also authorizes `*.example.com`, so this needs
only **3 `_acme-challenge` CNAME records**, added once, in the DNS console.

### Consequences

- **"Add a subdomain" becomes:** add a `hostname` + rule to the relevant HTTPRoute and
  `kubectl apply`. **No certificate work at all** — the wildcard cert and its cert-map
  entry already cover `*.tornacampsites.com`. This is the main win.
- **DNS management is unchanged** — records are still added manually in the DNS console
  (Squarespace / Google Domains). Only the one-time `_acme-challenge` records are new.
- The `FrontendConfig` (HTTPS redirect + SSL policy) is replaced by a redirect
  `HTTPRoute` and a `GCPGatewayPolicy`.
- The GCP load balancer is **rebuilt** (new URL map, new target proxies, new forwarding
  rules) on a **new static IP**. Cutover is a DNS repoint, so it is reversible.
- The 16 `ManagedCertificate` CRDs and `allprojects-ingress.yaml` are deleted only after
  the Gateway is validated and stable.

### Non-goals

- No change to `coderprabhu-cluster` / `coderprabhu-ingress.yaml`.
- No change to application Deployments, Services, MongoDB, or storage.
- Not adopting Config Connector or Terraform in this pass.

---

## 2. Current state (captured 2026-09-06)

- **Static IP:** `allprojects-ip` = `34.98.91.174` (global), held by
  `k8s2-fr-…` / `k8s2-fs-…` forwarding rules of `allprojects-ingress`.
- **All 16 hostnames' A records already point at `34.98.91.174`.**
- **FrontendConfig `allprojects-ingress-security-config`:** `redirectToHttps.enabled: true`,
  `sslPolicy: allprojects-ingress-ssl-policy` (MODERN profile, min TLS 1.2).
- **Gateway API on the cluster:** only the **legacy 2021 preview** CRDs are installed
  (`*.networking.x-k8s.io`, `gatewaystates.networking.gke.io`; GatewayClasses
  `gke-l7-gxlb`, `gke-l7-rilb`). No resources use them. The modern GA Gateway API
  (`gateway.networking.k8s.io/v1`) is **not** enabled — `gatewayApiConfig.channel` is empty.
- **All backend Services are `NodePort`.** Gateway will create NEGs for them.

### Routing table (hostname → Service → port)

| Hostname | Service | Port | App group |
|---|---|---|---|
| `whatsgoodonmenu.com` | `menu-ui-backend` | 8080 | whatsgoodonmenu |
| `www.whatsgoodonmenu.com` | `menu-ui-backend` | 8080 | whatsgoodonmenu |
| `api.whatsgoodonmenu.com` | `menu-api-backend` | 8080 | whatsgoodonmenu |
| `coderprabhu.com` | `coderprabhu-ui-backend` | 8080 | coderprabhu |
| `www.coderprabhu.com` | `coderprabhu-ui-backend` | 8080 | coderprabhu |
| `api.coderprabhu.com` | `coderprabhu-api-backend` | 8080 | coderprabhu |
| `tornacampsites.com` | `new-camp-ui-backend` | 8080 | tornacampsites core |
| `www.tornacampsites.com` | `new-camp-ui-backend` | 8080 | tornacampsites core |
| `newapi.tornacampsites.com` | `camp-newapi-backend` | 8080 | tornacampsites core |
| `rentals.tornacampsites.com` | `rentalui-homepage` | 5175 | rentalui MFE |
| `car-rental.tornacampsites.com` | `rentalui-car-rental` | 5174 | rentalui MFE |
| `real-estate.tornacampsites.com` | `rentalui-real-estate` | 5176 | rentalui MFE |
| `hospitality.tornacampsites.com` | `rentalui-hospitality` | 5177 | rentalui MFE |
| `jewelry.tornacampsites.com` | `rentalui-jewelry` | 5173 | rentalui MFE |
| `gym.tornacampsites.com` | `rentalui-gym` | 5178 | rentalui MFE |
| `rentalapi.tornacampsites.com` | `rentalapi-backend` | 8080 | tornacampsites core |

---

## 3. Target architecture

```
                    allprojects-gw-ip (new global static IP)
                                 │
                    ┌────────────┴────────────┐
                    │   Gateway               │
                    │   gke-l7-global-        │  annotations:
                    │   external-managed      │   networking.gke.io/certmap: allprojects-cert-map
                    │                         │
                    │   listener :80  (HTTP)  │──► HTTPRoute "http-to-https-redirect"  (301 → https)
                    │   listener :443 (HTTPS) │──► HTTPRoutes below
                    └─────────────────────────┘
                                 │
   ┌───────────────┬─────────────┼───────────────┬────────────────────┐
   │ route-        │ route-      │ route-        │ route-             │
   │ whatsgoodon.. │ coderprabhu │ tornacampsit..│ rentalui           │
   │ (3 hostnames) │ (3)         │ core (4)      │ (6)                │
   └───────────────┴─────────────┴───────────────┴────────────────────┘

   GCPGatewayPolicy "allprojects-gw-policy"  → sslPolicy: allprojects-ingress-ssl-policy

   Certificate Manager:
     map  allprojects-cert-map
       entry  *.tornacampsites.com     → cert tornacampsites-wild
       entry  tornacampsites.com       → cert tornacampsites-wild
       entry  *.coderprabhu.com        → cert coderprabhu-wild
       entry  coderprabhu.com          → cert coderprabhu-wild
       entry  *.whatsgoodonmenu.com    → cert whatsgoodonmenu-wild
       entry  whatsgoodonmenu.com      → cert whatsgoodonmenu-wild
       entry  PRIMARY (default)        → cert tornacampsites-wild
```

Manifests will live in `gateway/`:
`gateway/allprojects-gateway.yaml`, `gateway/allprojects-gateway-policy.yaml`,
`gateway/httproute-redirect.yaml`, `gateway/httproute-*.yaml`.

---

## 4. Prerequisites (one-time)

```bash
# context
gcloud config set account prashantbhuruk88@gmail.com
gcloud config set project all-projects-292200
gcloud container clusters get-credentials allprojects-cluster --zone us-west1-b

# enable APIs
gcloud services enable certificatemanager.googleapis.com

# enable the modern GA Gateway API on the cluster (installs gateway.networking.k8s.io/v1
# CRDs + modern GatewayClasses). Safe: no resources use the legacy preview CRDs.
gcloud container clusters update allprojects-cluster --zone us-west1-b \
  --gateway-api=standard

# verify
kubectl get gatewayclass gke-l7-global-external-managed
kubectl get crd gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io
```

> If the legacy `*.networking.x-k8s.io` CRDs cause a conflict, delete them only after
> confirming `kubectl get gateways.networking.x-k8s.io -A` is empty (it is, as of capture).

---

## 5. Migration runbook

Each phase lists **goal / steps / verify / rollback**. Phases 1–4 are non-disruptive —
the existing Ingress keeps serving all traffic. The only disruptive step is the DNS
cutover in Phase 5, and it is reversible.

### Phase 1 — Certificate Manager (non-disruptive)

**Goal:** three wildcard certs `ACTIVE` in a cert map, nothing attached to any LB yet.

1. Create the map:
   ```bash
   gcloud certificate-manager maps create allprojects-cert-map
   ```
2. For each apex domain (`tornacampsites.com`, `coderprabhu.com`, `whatsgoodonmenu.com`)
   create a DNS authorization:
   ```bash
   gcloud certificate-manager dns-authorizations create tornacampsites-dnsauth \
     --domain="tornacampsites.com" --type=FIXED_RECORD
   gcloud certificate-manager dns-authorizations describe tornacampsites-dnsauth \
     --format="value(dnsResourceRecord.name, dnsResourceRecord.type, dnsResourceRecord.data)"
   ```
   Repeat for `coderprabhu-dnsauth`, `whatsgoodonmenu-dnsauth`.
3. **STOP.** Add the 3 CNAME records in the DNS console (Squarespace / Google Domains).
   Each looks like:
   ```
   _acme-challenge.tornacampsites.com.  CNAME  <uuid>.<zone>.authorize.certificatemanager.goog.
   ```
   Wait until each resolves:
   ```bash
   dig +short CNAME _acme-challenge.tornacampsites.com
   ```
4. Create the certs (each references its DNS authorization):
   ```bash
   gcloud certificate-manager certificates create tornacampsites-wild \
     --domains="tornacampsites.com,*.tornacampsites.com" \
     --dns-authorizations=tornacampsites-dnsauth
   ```
   Repeat for `coderprabhu-wild`, `whatsgoodonmenu-wild`.
5. Create map entries:
   ```bash
   gcloud certificate-manager maps entries create tornacampsites-apex \
     --map=allprojects-cert-map --hostname="tornacampsites.com" \
     --certificates=tornacampsites-wild
   gcloud certificate-manager maps entries create tornacampsites-wild \
     --map=allprojects-cert-map --hostname="*.tornacampsites.com" \
     --certificates=tornacampsites-wild
   # ... coderprabhu, whatsgoodonmenu ...
   # default / catch-all entry:
   gcloud certificate-manager maps entries create default-primary \
     --map=allprojects-cert-map --certificates=tornacampsites-wild
   ```

**Verify:**
```bash
gcloud certificate-manager certificates list \
  --format="table(name, managed.state, managed.domains)"
# all three -> ACTIVE
gcloud certificate-manager maps entries list --map=allprojects-cert-map
```

**Rollback:** delete the entries, certs, map, dns-authorizations, and the 3 CNAME
records. Nothing else is affected.

### Phase 2 — Reserve the Gateway static IP (non-disruptive)

```bash
gcloud compute addresses create allprojects-gw-ip --global --ip-version=IPV4
gcloud compute addresses describe allprojects-gw-ip --global --format="value(address)"
```
Record the address here: `__________________`

### Phase 3 — Gateway + HTTPRoutes (non-disruptive, runs alongside Ingress)

**Goal:** a working Gateway on `allprojects-gw-ip`, serving all 16 hostnames, with the
Ingress still live on `34.98.91.174`.

1. `gateway/allprojects-gateway.yaml`:
   ```yaml
   apiVersion: gateway.networking.k8s.io/v1
   kind: Gateway
   metadata:
     name: allprojects-gateway
     annotations:
       networking.gke.io/certmap: allprojects-cert-map
   spec:
     gatewayClassName: gke-l7-global-external-managed
     addresses:
     - type: NamedAddress
       value: allprojects-gw-ip
     listeners:
     - name: http
       protocol: HTTP
       port: 80
     - name: https
       protocol: HTTPS
       port: 443
       # TLS is supplied by the certmap annotation; no tls.certificateRefs.
   ```
2. `gateway/allprojects-gateway-policy.yaml` — SSL policy (min TLS 1.2), replacing the
   FrontendConfig `sslPolicy`:
   ```yaml
   apiVersion: networking.gke.io/v1
   kind: GCPGatewayPolicy
   metadata:
     name: allprojects-gw-policy
   spec:
     targetRef:
       group: gateway.networking.k8s.io
       kind: Gateway
       name: allprojects-gateway
     default:
       sslPolicy: allprojects-ingress-ssl-policy
   ```
   > Verify the exact `GCPGatewayPolicy` schema at apply time (`kubectl explain
   > gcpgatewaypolicy.spec`) — field names have changed across GKE versions.
3. `gateway/httproute-redirect.yaml` — HTTP→HTTPS 301, replacing the FrontendConfig
   `redirectToHttps`:
   ```yaml
   apiVersion: gateway.networking.k8s.io/v1
   kind: HTTPRoute
   metadata:
     name: http-to-https-redirect
   spec:
     parentRefs:
     - name: allprojects-gateway
       sectionName: http
     rules:
     - filters:
       - type: RequestRedirect
         requestRedirect:
           scheme: https
           statusCode: 301
   ```
4. One HTTPRoute per app group, each attached to the `https` listener. Example
   `gateway/httproute-rentalui.yaml`:
   ```yaml
   apiVersion: gateway.networking.k8s.io/v1
   kind: HTTPRoute
   metadata:
     name: route-rentalui
   spec:
     parentRefs:
     - name: allprojects-gateway
       sectionName: https
     hostnames:
     - rentals.tornacampsites.com
     - car-rental.tornacampsites.com
     - real-estate.tornacampsites.com
     - hospitality.tornacampsites.com
     - jewelry.tornacampsites.com
     - gym.tornacampsites.com
     rules:
     - matches: [{ path: { type: PathPrefix, value: / } }]
       backendRefs: [{ name: rentalui-homepage, port: 5175 }]   # rentals.*
     # ...one rule per hostname; use per-hostname HTTPRoutes if clearer...
   ```
   > Simpler and less error-prone: **one HTTPRoute per hostname** (16 small files), each
   > with a single `backendRef`. Verbose but unambiguous and easy to diff when adding a
   > domain. Decide before writing.
5. Apply and wait:
   ```bash
   kubectl apply -f gateway/
   kubectl describe gateway allprojects-gateway   # Programmed=True, address assigned
   kubectl get httproute                          # each Accepted=True, ResolvedRefs=True
   ```
   Gateway LB provisioning takes ~5–10 min; NEG creation for the NodePort Services a few
   more.

**Verify (every hostname, without touching DNS):**
```bash
GW_IP=$(gcloud compute addresses describe allprojects-gw-ip --global --format='value(address)')
for h in whatsgoodonmenu.com www.whatsgoodonmenu.com api.whatsgoodonmenu.com \
         coderprabhu.com www.coderprabhu.com api.coderprabhu.com \
         tornacampsites.com www.tornacampsites.com newapi.tornacampsites.com \
         rentals.tornacampsites.com car-rental.tornacampsites.com \
         real-estate.tornacampsites.com hospitality.tornacampsites.com \
         jewelry.tornacampsites.com gym.tornacampsites.com rentalapi.tornacampsites.com; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --resolve "$h:443:$GW_IP" "https://$h/")
  redir=$(curl -s -o /dev/null -w '%{http_code}' --resolve "$h:80:$GW_IP" "http://$h/")
  echo "$h  https=$code  http=$redir(expect 301)"
done
```
All hostnames should return their normal status over HTTPS with a valid cert, and 301 on
HTTP. `gym.tornacampsites.com` should now work — that is the whole point.

**Rollback:** `kubectl delete -f gateway/`. Ingress is untouched throughout.

### Phase 4 — Lower DNS TTL (non-disruptive, do 24h before Phase 5)

In the DNS console, lower the TTL on all 16 A records (and apex) to 300s so the cutover
propagates fast and a rollback is quick.

### Phase 5 — DNS cutover (the one disruptive step; reversible)

1. In the DNS console, change every A record from `34.98.91.174` → `allprojects-gw-ip`.
   Records:
   `tornacampsites.com`, `www`, `newapi`, `rentals`, `car-rental`, `real-estate`,
   `hospitality`, `jewelry`, `rentalapi`, `gym` (`.tornacampsites.com`);
   `coderprabhu.com`, `www`, `api` (`.coderprabhu.com`);
   `whatsgoodonmenu.com`, `www`, `api` (`.whatsgoodonmenu.com`).
2. Watch traffic shift to the Gateway:
   ```bash
   watch -n5 'gcloud logging read "resource.type=http_load_balancer AND
     resource.labels.forwarding_rule_name:allprojects-gateway" --limit 5 --freshness=5m'
   ```
3. Spot-check each hostname from an external network (real DNS, not `--resolve`):
   ```bash
   for h in ...; do echo "$h $(curl -s -o /dev/null -w '%{http_code}' https://$h/)"; done
   ```

**Rollback:** revert the A records to `34.98.91.174`. Ingress is still running and still
has its certs. Propagation is ≤ the lowered TTL (300s).

### Phase 6 — Decommission (after ~1 week stable)

```bash
kubectl delete -f allprojects-ingress.yaml
kubectl delete managedcertificate --all        # all 16 (+ orphaned new.tornacampsites.com)
gcloud compute addresses delete allprojects-ip --global   # only once nothing references it
kubectl delete frontendconfig allprojects-ingress-security-config
```
Move `allprojects-ingress.yaml` and `allprojects-ingress-security-config.yaml` to
`archive/`. Update `CLAUDE.md` and `README.md` to describe the Gateway setup.
Keep `allprojects-ingress-ssl-policy` (still used by the `GCPGatewayPolicy`).

---

## 6. Post-migration runbooks

### Add a subdomain `foo.tornacampsites.com`

1. DNS console: add `A  foo.tornacampsites.com → <allprojects-gw-ip>`.
2. Add the hostname + a rule/route:
   - append `foo.tornacampsites.com` to `route-rentalui` (or the right group's) `hostnames`,
     and add a rule with the backend Service + port; **or** add a new
     `gateway/httproute-foo.yaml`.
3. `kubectl apply -f gateway/` and check `kubectl get httproute route-... -o yaml` for
   `Accepted=True`, `ResolvedRefs=True`.
4. **No certificate work** — `*.tornacampsites.com` is already covered by
   `tornacampsites-wild` and its cert-map entry.

Verify: `curl -sI https://foo.tornacampsites.com/` — valid cert, expected status.

### Add a subdomain under a *new* apex domain

Then you do need a cert: create `<apex>-dnsauth`, add its `_acme-challenge` CNAME,
create `<apex>-wild` cert (`apex, *.apex`), add two map entries, then proceed as above.

### Remove a subdomain

Remove the hostname/route from the HTTPRoute, `kubectl apply`, then delete the A record.
No cert change.

---

## 7. Open items / risks

- [x] Account: **`prashantbhuruk88@gmail.com`** (owner on `all-projects-292200`) owns
      these resources. Supersedes the `sanskruti2489@gmail.com` note in CLAUDE.md for the
      Gateway/Certificate Manager resources.
- [x] DNS console access for all three apex domains confirmed available to the operator.
- [ ] Decide: one HTTPRoute per app group vs one per hostname.
- [ ] Verify `GCPGatewayPolicy` schema on GKE 1.36 (`kubectl explain`).
- [ ] Verify Certificate Manager wildcard cert-map-entry behavior and whether a
      `PRIMARY` matcher entry is required for the target proxy default cert.
- [ ] Decide whether to accept wildcard certs (broader blast radius if a key leaks) vs
      explicit SAN lists (safer, but new subdomain under an existing apex = cert recreate).
- [ ] NodePort Services → NEG health checks: confirm each backend goes `HEALTHY` on the
      Gateway before cutover.
- [ ] `coderprabhu-api-backend` / several Services also expose `:443` — Gateway routes
      target `:8080` (HTTP) only, matching current Ingress behavior. Confirm no backend
      expects HTTPS from the LB.
