#!/usr/bin/env bash
# Keep-the-IP cutover: move allprojects-ip (34.98.91.174) from the old Ingress to
# the validated allprojects-v2 Gateway. NO DNS changes needed.
#
# Expect a short outage (~5-10 min) for ALL hostnames between the Ingress delete
# and the Gateway re-provisioning on 34.98.91.174. Run off-peak.
#
# HARD GATE: aborts unless the v2 Gateway is already serving tornacampsites.com
# (real customer traffic) + the rental subdomains green on the temp IP.
set -euo pipefail
cd "$(dirname "$0")/.."
OLD="${OLD_CONTEXT:-allprojects-cluster}"
NEW="${NEW_CONTEXT:-allprojects-v2}"
TEMP_IP=136.68.8.150
REAL_IP=34.98.91.174

echo ">> Gate: verifying v2 Gateway serves customer traffic on the temp IP ($TEMP_IP)"
GATE_HOSTS="tornacampsites.com www.tornacampsites.com rentals.tornacampsites.com car-rental.tornacampsites.com real-estate.tornacampsites.com hospitality.tornacampsites.com jewelry.tornacampsites.com gym.tornacampsites.com rentalapi.tornacampsites.com"
for h in $GATE_HOSTS; do
  c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 --resolve "$h:443:$TEMP_IP" "https://$h/" || echo ERR)
  t=$(curl -s -o /dev/null -w '%{ssl_verify_result}' --max-time 20 --resolve "$h:443:$TEMP_IP" "https://$h/" || echo ERR)
  case "$c" in 2*|3*) ;; *) echo "   ABORT: $h -> $c (tls=$t) not healthy on v2"; exit 1;; esac
  [ "$t" = 0 ] || { echo "   ABORT: $h TLS verify=$t on v2"; exit 1; }
  echo "   ok  $h ($c)"
done

echo
echo ">> Deleting the old Ingress (releases $REAL_IP). OUTAGE STARTS NOW."
kubectl --context "$OLD" delete -f allprojects-ingress.yaml --wait=true
kubectl --context "$OLD" delete -f allprojects-ingress-security-config.yaml --ignore-not-found

echo ">> Waiting for $REAL_IP to be released by the old load balancer"
for i in $(seq 1 60); do
  st=$(gcloud compute addresses describe allprojects-ip --global --format='value(status)' 2>/dev/null || echo "?")
  echo "   [$i] allprojects-ip status=$st"
  [ "$st" = RESERVED ] && break
  sleep 15
done

echo ">> Pointing the v2 Gateway at allprojects-ip"
kubectl --context "$NEW" patch gateway allprojects-gateway --type=merge \
  -p '{"spec":{"addresses":[{"type":"NamedAddress","value":"allprojects-ip"}]}}'

echo ">> Waiting for the v2 Gateway to program on $REAL_IP"
for i in $(seq 1 60); do
  addr=$(kubectl --context "$NEW" get gateway allprojects-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")
  prog=$(kubectl --context "$NEW" get gateway allprojects-gateway -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "")
  echo "   [$i] address=$addr programmed=$prog"
  [ "$addr" = "$REAL_IP" ] && [ "$prog" = True ] && break
  sleep 15
done

echo
echo ">> Verifying all hostnames on $REAL_IP (real DNS)"
HOSTS="
whatsgoodonmenu.com www.whatsgoodonmenu.com api.whatsgoodonmenu.com
coderprabhu.com www.coderprabhu.com api.coderprabhu.com
tornacampsites.com www.tornacampsites.com newapi.tornacampsites.com rentalapi.tornacampsites.com
rentals.tornacampsites.com car-rental.tornacampsites.com real-estate.tornacampsites.com
hospitality.tornacampsites.com jewelry.tornacampsites.com gym.tornacampsites.com
"
fail=0
for h in $HOSTS; do
  c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 --resolve "$h:443:$REAL_IP" "https://$h/" || echo ERR)
  r=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 --resolve "$h:80:$REAL_IP" "http://$h/" || echo ERR)
  case "$c" in 2*|3*) ok=1 ;; *) ok=0; fail=1 ;; esac
  printf '  %-32s https=%s http=%s %s\n' "$h" "$c" "$r" "$([ $ok = 1 ] && echo OK || echo CHECK)"
done
echo
if [ "$fail" = 0 ]; then
  echo ">> CUTOVER COMPLETE. allprojects-v2 is serving prod on $REAL_IP. Outage over."
  echo "   Old cluster still exists for rollback. Run 50-decommission.sh when confident."
else
  echo ">> PROBLEMS on $REAL_IP. Rollback: kubectl --context $OLD apply -f allprojects-ingress-security-config.yaml -f allprojects-ingress.yaml"
fi
