#!/usr/bin/env bash
# Phase 1b — create the three wildcard certificates and the certificate map
# entries. Run only after the Phase 1a CNAME records resolve.
# Non-disruptive: nothing is attached to any load balancer yet.
# See docs/gateway-api-migration.md.
set -euo pipefail

MAP="allprojects-cert-map"
# apex : dns-auth : cert name
CERTS=(
  "tornacampsites.com:tornacampsites-dnsauth:tornacampsites-wild"
  "coderprabhu.com:coderprabhu-dnsauth:coderprabhu-wild"
  "whatsgoodonmenu.com:whatsgoodonmenu-dnsauth:whatsgoodonmenu-wild"
)

echo ">> Pre-check: CNAME records must resolve"
for pair in "${CERTS[@]}"; do
  domain="${pair%%:*}"
  if [ -z "$(dig +short CNAME "_acme-challenge.${domain}")" ]; then
    echo "   MISSING: _acme-challenge.${domain} does not resolve yet. Aborting."
    exit 1
  fi
  echo "   ok: _acme-challenge.${domain}"
done

for pair in "${CERTS[@]}"; do
  domain="${pair%%:*}"; rest="${pair#*:}"; auth="${rest%%:*}"; cert="${rest##*:}"
  echo ">> Certificate: $cert  (${domain}, *.${domain})  auth=$auth"
  gcloud certificate-manager certificates describe "$cert" >/dev/null 2>&1 \
    && echo "   (already exists)" \
    || gcloud certificate-manager certificates create "$cert" \
         --domains="${domain},*.${domain}" \
         --dns-authorizations="$auth"

  echo ">> Map entries for $cert"
  gcloud certificate-manager maps entries describe "${cert}-apex" --map="$MAP" >/dev/null 2>&1 \
    || gcloud certificate-manager maps entries create "${cert}-apex" \
         --map="$MAP" --hostname="${domain}" --certificates="$cert"
  gcloud certificate-manager maps entries describe "${cert}-wildcard" --map="$MAP" >/dev/null 2>&1 \
    || gcloud certificate-manager maps entries create "${cert}-wildcard" \
         --map="$MAP" --hostname="*.${domain}" --certificates="$cert"
done

echo ">> Primary (default) map entry -> tornacampsites-wild"
gcloud certificate-manager maps entries describe "default-primary" --map="$MAP" >/dev/null 2>&1 \
  || gcloud certificate-manager maps entries create "default-primary" \
       --map="$MAP" --set-primary --certificates="tornacampsites-wild"

echo
echo ">> Waiting for certificates to go ACTIVE (can take 10-60 min)"
for i in $(seq 1 60); do
  states=$(gcloud certificate-manager certificates list \
    --format="value(managed.state)" 2>/dev/null | sort -u | paste -sd, -)
  echo "   [$i] states: ${states:-<none>}"
  [ "$states" = "ACTIVE" ] && break
  sleep 30
done

echo
gcloud certificate-manager certificates list \
  --format="table(name, managed.state, managed.domains)"
echo
gcloud certificate-manager maps entries list --map="$MAP" \
  --format="table(name, hostname, matcher, state)"
