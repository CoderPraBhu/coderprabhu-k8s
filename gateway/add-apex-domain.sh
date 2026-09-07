#!/usr/bin/env bash
# Onboard a brand-new apex domain onto the existing Gateway / cert map.
#
#   bash gateway/add-apex-domain.sh newbrand.com
#
# Run 1: creates the DNS authorization and prints the _acme-challenge CNAME.
#        -> add that CNAME in the domain's DNS console.
# Run 2 (after the CNAME resolves): creates the wildcard cert + 2 cert-map
#        entries and waits for ACTIVE.
#
# Does NOT touch the Gateway, its IP, or routing — after this, add HTTPRoute
# hostnames and the public A records (steps 5-7 in docs/gateway-api-migration.md).
set -euo pipefail

APEX="${1:?usage: add-apex-domain.sh <apex-domain>   e.g. newbrand.com}"
SLUG="$(echo "$APEX" | sed 's/\.[^.]*$//' | tr '.' '-')"   # newbrand.com -> newbrand
AUTH="${SLUG}-dnsauth"
CERT="${SLUG}-wild"
MAP="allprojects-cert-map"

if ! gcloud certificate-manager maps describe "$MAP" >/dev/null 2>&1; then
  echo "ERROR: cert map '$MAP' not found — is the migration done?" >&2; exit 1
fi

# ---- Step 1: DNS authorization -------------------------------------------------
if ! gcloud certificate-manager dns-authorizations describe "$AUTH" >/dev/null 2>&1; then
  echo ">> Creating DNS authorization $AUTH ($APEX)"
  gcloud certificate-manager dns-authorizations create "$AUTH" \
    --domain="$APEX" --type=FIXED_RECORD
fi

read -r RN RT RD < <(gcloud certificate-manager dns-authorizations describe "$AUTH" \
  --format="value(dnsResourceRecord.name,dnsResourceRecord.type,dnsResourceRecord.data)")

if [ -z "$(dig +short CNAME "_acme-challenge.${APEX}" @8.8.8.8)" ]; then
  cat <<EOF

============================================================================
 ADD THIS CNAME RECORD IN THE DNS CONSOLE, THEN RE-RUN THIS SCRIPT
============================================================================
  NAME  : $RN
  TYPE  : $RT
  VALUE : $RD

  verify: dig +short CNAME _acme-challenge.${APEX}
EOF
  exit 0
fi
echo ">> _acme-challenge.${APEX} resolves — continuing"

# ---- Step 2: wildcard certificate + cert-map entries -------------------------
if ! gcloud certificate-manager certificates describe "$CERT" >/dev/null 2>&1; then
  echo ">> Creating wildcard certificate $CERT ($APEX, *.$APEX)"
  gcloud certificate-manager certificates create "$CERT" \
    --domains="${APEX},*.${APEX}" --dns-authorizations="$AUTH"
fi

gcloud certificate-manager maps entries describe "${CERT}-apex" --map="$MAP" >/dev/null 2>&1 \
  || gcloud certificate-manager maps entries create "${CERT}-apex" \
       --map="$MAP" --hostname="${APEX}" --certificates="$CERT"
gcloud certificate-manager maps entries describe "${CERT}-wildcard" --map="$MAP" >/dev/null 2>&1 \
  || gcloud certificate-manager maps entries create "${CERT}-wildcard" \
       --map="$MAP" --hostname="*.${APEX}" --certificates="$CERT"

echo ">> Waiting for $CERT to go ACTIVE (10-30 min)"
for i in $(seq 1 60); do
  st=$(gcloud certificate-manager certificates describe "$CERT" --format="value(managed.state)" 2>/dev/null)
  echo "   [$i] $st"
  [ "$st" = "ACTIVE" ] && break
  sleep 30
done

echo
echo ">> Cert + map entries done. Next (see docs/gateway-api-migration.md step 5-7):"
echo "   - add HTTPRoute hostnames for $APEX under the 'https' listener"
echo "   - add public A records: $APEX, www.$APEX, ... -> \$(gcloud compute addresses describe allprojects-gw-ip --global --format='value(address)')"
echo "   - optional: CAA 0 issue \"pki.goog\""
