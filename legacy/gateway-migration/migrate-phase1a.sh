#!/usr/bin/env bash
# Phase 1a — create the certificate map and the three DNS authorizations.
# Non-disruptive: nothing is attached to any load balancer.
# After this runs, add the printed CNAME records in the DNS console, then run
# migrate-phase1b.sh. See docs/gateway-api-migration.md.
set -euo pipefail

MAP="allprojects-cert-map"
# apex domain  ->  dns-authorization name
APEXES=(
  "tornacampsites.com:tornacampsites-dnsauth"
  "coderprabhu.com:coderprabhu-dnsauth"
  "whatsgoodonmenu.com:whatsgoodonmenu-dnsauth"
)

echo ">> Creating certificate map: $MAP"
gcloud certificate-manager maps describe "$MAP" >/dev/null 2>&1 \
  && echo "   (already exists)" \
  || gcloud certificate-manager maps create "$MAP"

for pair in "${APEXES[@]}"; do
  domain="${pair%%:*}"; auth="${pair##*:}"
  echo ">> DNS authorization: $auth  ($domain)"
  gcloud certificate-manager dns-authorizations describe "$auth" >/dev/null 2>&1 \
    && echo "   (already exists)" \
    || gcloud certificate-manager dns-authorizations create "$auth" \
         --domain="$domain" --type=FIXED_RECORD
done

echo
echo "============================================================================"
echo " ADD THESE 3 CNAME RECORDS IN THE DNS CONSOLE (Squarespace / Google Domains)"
echo "============================================================================"
for pair in "${APEXES[@]}"; do
  domain="${pair%%:*}"; auth="${pair##*:}"
  read -r name type data < <(gcloud certificate-manager dns-authorizations describe "$auth" \
      --format="value(dnsResourceRecord.name, dnsResourceRecord.type, dnsResourceRecord.data)")
  echo
  echo "  domain : $domain"
  echo "  NAME   : $name"
  echo "  TYPE   : $type"
  echo "  VALUE  : $data"
done
echo
echo "----------------------------------------------------------------------------"
echo "Then verify each resolves:"
echo "  dig +short CNAME _acme-challenge.tornacampsites.com"
echo "  dig +short CNAME _acme-challenge.coderprabhu.com"
echo "  dig +short CNAME _acme-challenge.whatsgoodonmenu.com"
echo "and run: bash gateway/migrate-phase1b.sh"
