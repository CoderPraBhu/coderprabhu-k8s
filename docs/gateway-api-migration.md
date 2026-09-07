# allprojects-cluster: Ingress → Gateway API + Certificate Manager migration

> ## ⚠️ BLOCKED at Phase 3 (2026-09-06)
> **`allprojects-cluster` is routes-based (`ipAllocationPolicy.useRoutes: true`), not
> VPC-native.** GKE Gateway only supports NEG (container-native) backends, which require
> VPC-native (alias IPs). The Gateway, forwarding rules, target proxies, and cert map all
> came up fine and TLS terminates correctly, but every backend NEG stays **size 0** — the
> routes-based cluster has no VM alias IPs to register pod endpoints — so every hostname
> returns **502**.
>
> **Routes-based → VPC-native is not an in-place change** (no `--enable-ip-alias` on
> `clusters update`). The Gateway path requires a **new VPC-native cluster**.
>
> The cluster is **fully stateless** (0 StatefulSets/PVC/PV; MongoDB is on Atlas; 8
> Deployments + Services), so a rebuild is tractable. Certificate Manager resources
> (cert map + 3 wildcard certs, all ACTIVE) are project-level and **carry over unchanged**.
>
> Decision pending — see §8.

**Status:** Blocked — started 2026-09-06
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
        one HTTPRoute per hostname/backend (13), file + route named
        httproute-<apex-slug>-<function> / route-<apex-slug>-<function>

   GCPGatewayPolicy "allprojects-gw-policy"  → sslPolicy: allprojects-ingress-ssl-policy

   Certificate Manager:
     map  allprojects-cert-map
       entry  tornacampsites-wild-apex      hostname tornacampsites.com      → tornacampsites-wild
       entry  tornacampsites-wild-wildcard  hostname *.tornacampsites.com    → tornacampsites-wild
       entry  coderprabhu-wild-apex         hostname coderprabhu.com         → coderprabhu-wild
       entry  coderprabhu-wild-wildcard     hostname *.coderprabhu.com       → coderprabhu-wild
       entry  whatsgoodonmenu-wild-apex     hostname whatsgoodonmenu.com     → whatsgoodonmenu-wild
       entry  whatsgoodonmenu-wild-wildcard hostname *.whatsgoodonmenu.com   → whatsgoodonmenu-wild
       entry  default-primary               (--set-primary)                  → tornacampsites-wild
```

Manifests in `gateway/`: `allprojects-gateway.yaml` (Gateway + GCPGatewayPolicy),
`httproute-redirect.yaml`, and one `httproute-<apex-slug>-<function>.yaml` per
hostname/backend (see the table in Phase 3). `kubectl apply -f gateway/` applies all of
them (non-YAML files in the dir are ignored).

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
   Each is `_acme-challenge.<apex>. CNAME <uuid>.<n>.authorize.certificatemanager.goog.`
   Get the exact values (kept out of this repo) with:
   ```bash
   for a in tornacampsites-dnsauth coderprabhu-dnsauth whatsgoodonmenu-dnsauth; do
     gcloud certificate-manager dns-authorizations describe "$a" \
       --format="value(dnsResourceRecord.name,dnsResourceRecord.type,dnsResourceRecord.data)"
   done
   ```
   These records are permanent — leave them in place after the migration so the
   wildcard certs can auto-renew. Wait until each resolves:
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
**`allprojects-gw-ip` = `136.68.8.150`** (reserved 2026-09-06). The Ingress keeps
`allprojects-ip` = `34.98.91.174` until Phase 6.

### Phase 3 — Gateway + HTTPRoutes (non-disruptive, runs alongside Ingress)

**Goal:** a working Gateway on `allprojects-gw-ip`, serving all 16 hostnames, with the
Ingress still live on `34.98.91.174`.

1. **`gateway/allprojects-gateway.yaml`** — `Gateway` (`gke-l7-global-external-managed`,
   `networking.gke.io/certmap: allprojects-cert-map`, `addresses: [{type: NamedAddress,
   value: allprojects-gw-ip}]`, HTTP :80 + HTTPS :443 listeners, **no `tls:` block** —
   TLS comes from the certmap) plus the **`GCPGatewayPolicy`** `allprojects-gw-policy`
   (`spec.default.sslPolicy: allprojects-ingress-ssl-policy`, verified on GKE 1.36).
2. **`gateway/httproute-redirect.yaml`** — HTTP→HTTPS 301 (`RequestRedirect` filter on
   the `http` listener, hostname-agnostic). Replaces FrontendConfig `redirectToHttps`.
3. **One `HTTPRoute` per hostname/backend**, one file each, attached to the `https`
   listener:

   | File | Route name | Hostname(s) | Backend |
   |---|---|---|---|
   | `httproute-whatsgoodonmenu-ui.yaml` | `route-whatsgoodonmenu-ui` | `whatsgoodonmenu.com`, `www.` | `menu-ui-backend:8080` |
   | `httproute-whatsgoodonmenu-api.yaml` | `route-whatsgoodonmenu-api` | `api.whatsgoodonmenu.com` | `menu-api-backend:8080` |
   | `httproute-coderprabhu-ui.yaml` | `route-coderprabhu-ui` | `coderprabhu.com`, `www.` | `coderprabhu-ui-backend:8080` |
   | `httproute-coderprabhu-api.yaml` | `route-coderprabhu-api` | `api.coderprabhu.com` | `coderprabhu-api-backend:8080` |
   | `httproute-tornacampsites-ui.yaml` | `route-tornacampsites-ui` | `tornacampsites.com`, `www.` | `new-camp-ui-backend:8080` |
   | `httproute-tornacampsites-newapi.yaml` | `route-tornacampsites-newapi` | `newapi.tornacampsites.com` | `camp-newapi-backend:8080` |
   | `httproute-tornacampsites-rentalapi.yaml` | `route-tornacampsites-rentalapi` | `rentalapi.tornacampsites.com` | `rentalapi-backend:8080` |
   | `httproute-tornacampsites-rentals.yaml` | `route-tornacampsites-rentals` | `rentals.tornacampsites.com` | `rentalui-homepage:5175` |
   | `httproute-tornacampsites-car-rental.yaml` | `route-tornacampsites-car-rental` | `car-rental.tornacampsites.com` | `rentalui-car-rental:5174` |
   | `httproute-tornacampsites-real-estate.yaml` | `route-tornacampsites-real-estate` | `real-estate.tornacampsites.com` | `rentalui-real-estate:5176` |
   | `httproute-tornacampsites-hospitality.yaml` | `route-tornacampsites-hospitality` | `hospitality.tornacampsites.com` | `rentalui-hospitality:5177` |
   | `httproute-tornacampsites-jewelry.yaml` | `route-tornacampsites-jewelry` | `jewelry.tornacampsites.com` | `rentalui-jewelry:5173` |
   | `httproute-tornacampsites-gym.yaml` | `route-tornacampsites-gym` | `gym.tornacampsites.com` | `rentalui-gym:5178` |

   Naming: `httproute-<apex-slug>-<function>.yaml` / `route-<apex-slug>-<function>`. The
   `<function>` (`gym`, `car-rental`, `rentalapi`, …) is generic — the same rental
   micro-frontends can appear under another apex later as
   `httproute-<newapex>-gym.yaml` without collision.
4. Apply and wait:
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
2. Copy an existing single-hostname route file to
   `gateway/httproute-tornacampsites-foo.yaml`, set `metadata.name:
   route-tornacampsites-foo`, the `hostnames`, and the `backendRefs` Service + port.
3. `kubectl apply -f gateway/httproute-tornacampsites-foo.yaml` and check
   `kubectl get httproute route-tornacampsites-foo -o yaml` for `Accepted=True`,
   `ResolvedRefs=True`.
4. **No certificate work** — `*.tornacampsites.com` is already covered by
   `tornacampsites-wild` and its cert-map entry.

Verify: `curl -sI https://foo.tornacampsites.com/` — valid cert, expected status.

Template (single hostname → single backend):
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

### Onboard a brand-new apex domain (e.g. a newly procured `newbrand.com`)

This is the full checklist for bringing a new top-level domain onto the existing
Gateway. The Gateway, its IP, and the `GCPGatewayPolicy` do **not** change — the new
domain is added by (a) one wildcard cert + two cert-map entries in the existing
`allprojects-cert-map`, and (b) HTTPRoute hostnames. Steps 1–5 are non-disruptive;
nothing is user-visible until the A records in step 6 point at the Gateway.

**Prerequisites:** the domain is registered and you can edit its DNS zone. Squarespace's
DNS editor *does* accept the long `_acme-challenge` CNAME value (verified 2026-09-06).

1. **Set context** (once per session):
   ```bash
   gcloud config set account prashantbhuruk88@gmail.com
   gcloud config set project all-projects-292200
   gcloud container clusters get-credentials allprojects-cluster --zone us-west1-b
   ```

2. **Create the DNS authorization** for the apex (covers `newbrand.com` *and*
   `*.newbrand.com` — one authorization is enough for the wildcard):
   ```bash
   gcloud certificate-manager dns-authorizations create newbrand-dnsauth \
     --domain="newbrand.com" --type=FIXED_RECORD
   gcloud certificate-manager dns-authorizations describe newbrand-dnsauth \
     --format="value(dnsResourceRecord.name,dnsResourceRecord.type,dnsResourceRecord.data)"
   ```

3. **STOP — add the printed `_acme-challenge.newbrand.com` CNAME** in the domain's DNS
   console. Wait until it resolves:
   ```bash
   dig +short CNAME _acme-challenge.newbrand.com
   ```

4. **Create the wildcard certificate and its two cert-map entries:**
   ```bash
   gcloud certificate-manager certificates create newbrand-wild \
     --domains="newbrand.com,*.newbrand.com" \
     --dns-authorizations=newbrand-dnsauth

   gcloud certificate-manager maps entries create newbrand-wild-apex \
     --map=allprojects-cert-map --hostname="newbrand.com" \
     --certificates=newbrand-wild
   gcloud certificate-manager maps entries create newbrand-wild-wildcard \
     --map=allprojects-cert-map --hostname="*.newbrand.com" \
     --certificates=newbrand-wild
   ```
   Wait for `ACTIVE`:
   ```bash
   gcloud certificate-manager certificates describe newbrand-wild \
     --format="value(managed.state)"     # -> ACTIVE (10-30 min)
   ```
   The Gateway picks up the new map entries automatically — no Gateway edit, no restart.

   Steps 2–4 are packaged as: **`bash gateway/add-apex-domain.sh newbrand.com`**
   (it stops after step 2 to let you add the CNAME, then re-run to finish).

5. **Add routing.** For each hostname the new domain serves, add it to an HTTPRoute
   attached to the `https` listener with a `backendRef` to the right Service/port
   (see the routing table in §2 for the pattern), e.g. `gateway/httproute-newbrand.yaml`:
   ```yaml
   apiVersion: gateway.networking.k8s.io/v1
   kind: HTTPRoute
   metadata:
     name: route-newbrand
   spec:
     parentRefs:
     - { name: allprojects-gateway, sectionName: https }
     hostnames: [ "newbrand.com", "www.newbrand.com" ]
     rules:
     - matches: [{ path: { type: PathPrefix, value: / } }]
       backendRefs: [{ name: <service>, port: <port> }]
   ```
   Also append the hostnames to `gateway/httproute-redirect.yaml` if that route pins
   hostnames (it does not by default — the redirect route is hostname-agnostic).
   ```bash
   kubectl apply -f gateway/
   kubectl get httproute route-newbrand -o yaml   # Accepted=True, ResolvedRefs=True
   ```

6. **Point DNS at the Gateway.** In the DNS console add A records for `newbrand.com`,
   `www.newbrand.com`, and any other hostnames → the Gateway IP
   (`gcloud compute addresses describe allprojects-gw-ip --global --format='value(address)'`).
   Recommended: also add `CAA 0 issue "pki.goog"` (matches `coderprabhu.com`).

7. **Verify:**
   ```bash
   for h in newbrand.com www.newbrand.com; do
     echo "$h  https=$(curl -s -o /dev/null -w '%{http_code}' https://$h/)  http=$(curl -s -o /dev/null -w '%{http_code}' http://$h/)"
   done
   ```
   Valid cert, expected status, `301` on HTTP.

**Rollback:** delete the A records; `kubectl delete httproute route-newbrand`; delete the
two map entries, the cert, and the dns-authorization. Nothing else is affected.

### Add a subdomain under an existing apex (`foo.tornacampsites.com`)

1. DNS console: `A  foo.tornacampsites.com → <allprojects-gw-ip>`.
2. Add `foo.tornacampsites.com` to the relevant HTTPRoute's `hostnames` + a rule with the
   backend Service/port (or a new `gateway/httproute-foo.yaml`). `kubectl apply -f gateway/`.
3. **No certificate work** — `*.tornacampsites.com` is already covered by `tornacampsites-wild`.

Verify: `curl -sI https://foo.tornacampsites.com/`.

### Remove a subdomain

Remove the hostname/route from the HTTPRoute, `kubectl apply`, then delete the A record.
No cert change. To fully retire an apex domain, also delete its `<apex>-wild*` map
entries, the `<apex>-wild` cert, and `<apex>-dnsauth`.

---

## 7. Open items / risks

- [x] Account: **`prashantbhuruk88@gmail.com`** (owner on `all-projects-292200`) owns
      these resources. Supersedes the `sanskruti2489@gmail.com` note in CLAUDE.md for the
      Gateway/Certificate Manager resources.
- [x] DNS console access for all three apex domains confirmed available to the operator.
- [x] HTTPRoute layout: **one route per hostname/backend, one file each**, named
      `httproute-<apex-slug>-<function>.yaml`. `<function>` is generic so rental
      micro-frontends can recur under a future apex without name collisions.
- [x] `GCPGatewayPolicy` schema verified on GKE 1.36: `spec.default.sslPolicy` (string),
      `spec.targetRef` {group,kind,name}. Manifest: `gateway/allprojects-gateway.yaml`.
- [x] Wildcard cert-map entries: created apex + `*.apex` entries per domain plus one
      `--set-primary` entry — all 7 `ACTIVE`. Certs `ACTIVE` in ~4 min.
- [x] Wildcard certs accepted (removes per-subdomain cert ops; matches the "agent adds a
      domain" workflow). Blast radius noted; CAA `pki.goog` already set on coderprabhu.com.
- [ ] NodePort Services → NEG health checks: confirm each backend goes `HEALTHY` on the
      Gateway in Phase 3 before cutover. No `BackendConfig` exists; Gateway derives health
      checks from pod readiness probes (UI services have none → default `GET /` check).
- [ ] `coderprabhu-api-backend` / several Services also expose `:443` — Gateway routes
      target `:8080` (HTTP) only, matching current Ingress behavior. Confirm no backend
      expects HTTPS from the LB.

---

## 8. BLOCKER — routes-based cluster, decision needed

### What we know
- Gateway control plane works: `allprojects-gateway` `Programmed=True` on `136.68.8.150`,
  all 13 HTTPRoutes `Accepted`/`ResolvedRefs=True`, cert map attached, TLS verifies
  (`ssl_verify_result=0`), SSL policy applied.
- Data plane is dead: all `k8s1-…` NEGs are **size 0**, every hostname → **502**.
  Cause: `useRoutes: true`. NEGs need VPC-native.
- No in-place fix. The current Ingress keeps working (instance-group backends, which are
  fine on routes-based) and is untouched.

### Option A — Rebuild as a VPC-native cluster, then finish the Gateway migration
Because the cluster is stateless this is mostly re-apply:
1. `gcloud container clusters create allprojects-v2 --enable-ip-alias --zone us-west1-b …`
   (match machine type e2-custom-2-3072, RAPID channel, GcePersistentDiskCsiDriver off).
2. `--gateway-api=standard` on the new cluster.
3. `kubectl apply` all app Deployments + Services, then `kubectl apply -f gateway/`.
4. Certificate Manager: **no change** — cert map + certs are project-global and already
   ACTIVE. The new Gateway references `allprojects-cert-map` by name.
5. Reuse `allprojects-gw-ip` (136.68.8.150); validate with `curl --resolve`.
6. DNS cutover (Phase 5), then delete the old cluster + its Ingress + ManagedCertificates.
- **Pros:** ends on the modern stack (VPC-native + Gateway + Certificate Manager, wildcard
  certs, agent-friendly "add a domain"). Clears 5-year-old cluster cruft.
- **Cons:** new cluster, re-apply every workload, a real cutover. Node-level differences
  (NEG health checks, pod CIDR) to shake out.

### Option B — Abandon Gateway, stay on the Ingress and consolidate certs
1. `kubectl delete -f gateway/`; release `allprojects-gw-ip`; `--gateway-api=disabled`
   (optional).
2. Replace the 16 single-domain `ManagedCertificate` objects with a few multi-SAN ones
   (classic managed certs **do not support wildcards**, but up to 100 SANs each):
   - `wgom-cert`: whatsgoodonmenu.com, www., api.
   - `coderprabhu-cert`: coderprabhu.com, www., api.
   - `tornacampsites-cert`: tornacampsites.com, www., newapi., rentalapi., rentals.,
     car-rental., real-estate., hospitality., jewelry., gym.
   16 certs → 3, back under the 15-cert target-proxy limit; `gym` provisions.
3. Update `allprojects-ingress.yaml` `networking.gke.io/managed-certificates` to the 3.
- **Pros:** low risk, no cutover, fixes `gym` today, keeps the working cluster.
- **Cons:** stays on routes-based + Ingress (frozen API). `spec.domains` is immutable —
  adding a subdomain later means recreating a multi-SAN cert (all its domains
  re-provision, brief). Keep spare cert slots for new singles.

### Option C — Keep the Certificate Manager cert map for later, do Option B now
Same as B, but leave `allprojects-cert-map` + the 3 wildcard certs in place (they cost
nothing) so a future VPC-native rebuild can pick up the Gateway path with the cert work
already done. The dns-authorization CNAMEs stay in DNS.

### Recommendation
If a cluster rebuild is on the table anyway (this one is old, single-node, routes-based),
**Option A** is the clean end state. If not, **Option C** — fix `gym` now via consolidation,
keep the cert-map groundwork for whenever the cluster is next rebuilt.

---

## 9. DECISION: Option A — rebuild VPC-native (2026-09-06)

New cluster **`allprojects-v2`**: same zone / machine type / RAPID channel as
`allprojects-cluster`, plus `--enable-ip-alias` (VPC-native) and `--gateway-api=standard`.
Pod range `10.100.0.0/14`, service range `10.104.0.0/20` — deliberately clear of the old
cluster's `10.0.0.0/14` / `10.3.240.0/20` so both run in parallel during cutover.

Scripts in `migration/` (run in order; `snapshot/` is gitignored — it holds Secrets):

| Step | Script | Disruptive? | What it does |
|---|---|---|---|
| 0 | `00-snapshot.sh` | no (read-only) | Dumps the 8 app Deployments + 14 Services + 4 ConfigMaps + 8 Secrets + the `default-view` CRB from `allprojects-cluster` to `migration/snapshot/`, cleaned of cluster-specific fields (`clean-manifest.py`). |
| 1 | `10-create-cluster.sh` | no | Creates `allprojects-v2` (VPC-native, Gateway API standard). ~8 min. |
| 2 | `20-restore-workloads.sh` | no | Applies the snapshot to `allprojects-v2`, waits for all 8 rollouts + endpoints. |
| 3 | `30-deploy-gateway.sh` | no | Deletes the stale broken Gateway from the **old** cluster (frees `136.68.8.150`), applies `gateway/` to `allprojects-v2`, waits for `Programmed`, probes all 16 hostnames via `curl --resolve`. NEGs should now populate (VPC-native). |
| 4 | `40-cutover-keep-ip.sh` | **yes — brief outage** | **Keep-the-IP cutover, no DNS changes.** Gate: v2 must already serve `tornacampsites.com` + rental subdomains green on the temp IP. Then: delete old Ingress → wait for `allprojects-ip` to release → `kubectl patch` the v2 Gateway's address to `allprojects-ip` → wait for it to program on `34.98.91.174` → verify all 16 hosts. Expect **~5–10 min outage** for every hostname during the IP move. |
| 5 | `50-decommission.sh` | yes | After v2 has served prod OK: delete old ManagedCertificates, delete `allprojects-cluster`, release the temp `allprojects-gw-ip`. |

### Cutover choice: keep the IP (no DNS edits)
Per operator instruction — proceed autonomously, no wait for sign-off, cut over as long as
the tornacampsites pods are healthy on v2. `allprojects-ip` (`34.98.91.174`) moves from the
old Ingress to the v2 Gateway, so **no DNS records change**. Cost: a single ~5–10 min
outage window (all hostnames) while GCP releases the IP and re-provisions the Gateway
frontend on it. Rollback within the window: re-apply `allprojects-ingress*.yaml` on the old
cluster. After a clean cutover, `gateway/allprojects-gateway.yaml` is updated to reference
`allprojects-ip` permanently and `allprojects-gw-ip` is released.

### Carries over unchanged
- **Certificate Manager**: `allprojects-cert-map` + 3 wildcard certs (all `ACTIVE`) are
  project-global. The new Gateway references the map by name — no cert work.
- **`allprojects-gw-ip`** (`136.68.8.150`) — reused; freed from the old Gateway in step 3.
- **`allprojects-ingress-ssl-policy`** — kept, referenced by the `GCPGatewayPolicy`.
- **Container images** — all `gcr.io/all-projects-292200/…`, same project; the new node
  SA (default Compute SA + `devstorage.read_only` scope) pulls them.

### Not handled by these scripts (manual follow-up)
- **Cloud Build deploy triggers.** 6 of the 8 apps are deployed by `gcp-cloud-build-deploy`
  from their own repos (coderprabhu-ui, campui, campapi, whatsgoodonmenuui, rentalui,
  rentalapi). After cutover, update each trigger's cluster target
  (`_GKE_CLUSTER` substitution / `gke-deploy --cluster`) from `allprojects-cluster`
  → `allprojects-v2`, else the next app deploy lands on the deleted cluster.
- `CLAUDE.md` cluster table + `README.md` — update once `allprojects-v2` is live.
- `coderprabhu-api-app` and `menu-api-app` are deployed **manually from the operator's
  local CLI** (`kubectl apply`). After cutover, run those against the `allprojects-v2`
  context. The snapshot captures their currently-running versions, so nothing is lost.

---

## 10. Cloud Build repoint (so future app deploys hit allprojects-v2)

6 apps deploy via Cloud Build; 2 (`coderprabhu-api`, `menu-api`) deploy manually from the
operator's CLI. After the cluster rename, deploys must target `allprojects-v2` or they land
on the deleted cluster.

### Repos with an in-tree `cloudbuild.yaml` (fixed on branch `deploy-to-allprojects-v2`)
| Repo | Change | Trigger |
|---|---|---|
| `campui` | `substitutions._GKE_CLUSTER: allprojects-cluster → allprojects-v2` | `automated-deployment-2` (uses file default) |
| `rentalapi` | same | `push-to-rental-api` (uses file default) |
| `rentalui` | same | `push-to-rental-ui` (uses file default) |
| `coderprabhu-api` | `env CLOUDSDK_CONTAINER_CLUSTER=allprojects-cluster → allprojects-v2` | manual / `sample-trigger-1` |

→ **merge + push** branch `deploy-to-allprojects-v2` in each of those 4 repos.

### Triggers that override `_GKE_CLUSTER` inline (no repo file) — `migration/45-repoint-cloudbuild.sh`
| Trigger | App | Repo |
|---|---|---|
| `automated-deployment-4` | `camp-newapi-app` | campapi |
| `automated-deployment-3` | `coderprabhu-ui-web` | coderprabhu-ui |
| `automated-deployment-1` | `menu-ui-web` | whatsgoodonmenuui |

```
gcloud builds triggers update <name> --update-substitutions=_GKE_CLUSTER=allprojects-v2
```

### Manual-deploy apps
`coderprabhu-api` and `menu-api` (`whatsgoodonmenuapi`): run `kubectl apply` against the
`allprojects-v2` context from now on. Their currently-running versions are already on v2
via the snapshot.

### After everything is repointed
Update `CLAUDE.md` (cluster table: `allprojects-cluster` → `allprojects-v2`, and the
`k8s/` deploy note) and `README.md`.
