#!/usr/bin/env bash
# Phase 3 — deploy the Gateway + HTTPRoutes alongside the running Ingress.
# Non-disruptive: the Ingress on 34.98.91.174 keeps serving all traffic. This
# only stands up a second load balancer on allprojects-gw-ip for validation.
set -euo pipefail
cd "$(dirname "$0")/.."

echo ">> Applying gateway manifests"
kubectl apply -f gateway/

echo
echo ">> Waiting for the Gateway to be programmed (LB provisioning, ~5-10 min)"
kubectl wait --for=condition=Programmed gateway/allprojects-gateway --timeout=900s || true
kubectl get gateway allprojects-gateway -o wide
echo
kubectl get httproute

GW_IP=$(gcloud compute addresses describe allprojects-gw-ip --global --format='value(address)')
echo
echo ">> Gateway IP: $GW_IP"
echo ">> Probing every hostname against the Gateway (DNS still points at the Ingress)"
HOSTS="
whatsgoodonmenu.com www.whatsgoodonmenu.com api.whatsgoodonmenu.com
coderprabhu.com www.coderprabhu.com api.coderprabhu.com
tornacampsites.com www.tornacampsites.com newapi.tornacampsites.com rentalapi.tornacampsites.com
rentals.tornacampsites.com car-rental.tornacampsites.com real-estate.tornacampsites.com
hospitality.tornacampsites.com jewelry.tornacampsites.com gym.tornacampsites.com
"
fail=0
for h in $HOSTS; do
  https=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 --resolve "$h:443:$GW_IP" "https://$h/" || echo ERR)
  http=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 --resolve "$h:80:$GW_IP" "http://$h/" || echo ERR)
  tls=$(curl -s -o /dev/null -w '%{ssl_verify_result}' --max-time 15 --resolve "$h:443:$GW_IP" "https://$h/" || echo ERR)
  flag=""
  case "$https" in 2*|3*) ;; *) flag=" <-- CHECK"; fail=1;; esac
  [ "$http" = "301" ] || { flag="$flag <-- redirect=$http"; fail=1; }
  [ "$tls" = "0" ] || { flag="$flag <-- tls_verify=$tls"; fail=1; }
  printf '  %-32s https=%s http=%s tls_verify=%s%s\n' "$h" "$https" "$http" "$tls" "$flag"
done
echo
[ "$fail" = 0 ] && echo ">> All hostnames OK on the Gateway. Ready for Phase 4/5 (DNS cutover)." \
                || echo ">> Some checks failed — investigate before cutover (backend health, route status)."
