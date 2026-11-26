#!/usr/bin/env bash
# Move the Gateway to allprojects-v2 and validate every hostname.
# The old cluster's Ingress on 34.98.91.174 stays up and serving throughout.
set -euo pipefail
cd "$(dirname "$0")/.."
OLD="${OLD_CONTEXT:-allprojects-cluster}"
NEW="${NEW_CONTEXT:-allprojects-v2}"
GW_IP=136.68.8.150

echo ">> Removing the stale (broken) Gateway from the OLD cluster to free $GW_IP"
kubectl --context "$OLD" delete -f gateway/ --ignore-not-found
echo "   waiting for forwarding rules on $GW_IP to be released..."
for i in $(seq 1 30); do
  n=$(gcloud compute forwarding-rules list --filter="IPAddress=$GW_IP" --format="value(name)" | wc -l | tr -d ' ')
  [ "$n" = "0" ] && break
  sleep 10
done

echo ">> Applying gateway manifests to $NEW"
kubectl --context "$NEW" apply -f gateway/
kubectl --context "$NEW" wait --for=condition=Programmed gateway/allprojects-gateway --timeout=900s || true
kubectl --context "$NEW" get gateway allprojects-gateway -o wide
kubectl --context "$NEW" get httproute

echo
echo ">> Probing every hostname against the new Gateway ($GW_IP); prod DNS unchanged"
HOSTS="
whatsgoodonmenu.com www.whatsgoodonmenu.com api.whatsgoodonmenu.com
coderprabhu.com www.coderprabhu.com api.coderprabhu.com
tornacampsites.com www.tornacampsites.com newapi.tornacampsites.com rentalapi.tornacampsites.com
rentals.tornacampsites.com car-rental.tornacampsites.com real-estate.tornacampsites.com
hospitality.tornacampsites.com jewelry.tornacampsites.com gym.tornacampsites.com
"
fail=0
for h in $HOSTS; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 --resolve "$h:443:$GW_IP" "https://$h/" || echo ERR)
  redir=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 --resolve "$h:80:$GW_IP" "http://$h/" || echo ERR)
  tls=$(curl -s -o /dev/null -w '%{ssl_verify_result}' --max-time 20 --resolve "$h:443:$GW_IP" "https://$h/" || echo ERR)
  bad=""
  case "$code" in 2*|3*) ;; *) bad=" CHECK"; fail=1;; esac
  [ "$redir" = 301 ] || { bad="$bad redirect=$redir"; fail=1; }
  [ "$tls" = 0 ] || { bad="$bad tls=$tls"; fail=1; }
  printf '  %-32s https=%s http=%s tls=%s%s\n' "$h" "$code" "$redir" "$tls" "$bad"
done
echo
[ "$fail" = 0 ] && echo ">> ALL GREEN. Proceed to DNS cutover (Phase 5 in docs/gateway-api-migration.md)." \
                || echo ">> Failures above — do NOT cut over. Check NEG size / backend health on $NEW."
