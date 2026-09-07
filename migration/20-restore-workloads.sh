#!/usr/bin/env bash
# Apply the snapshot (config, secrets, deployments, services) to allprojects-v2,
# then wait for all app pods to become Ready.
set -euo pipefail
cd "$(dirname "$0")"
NEW="${NEW_CONTEXT:-allprojects-v2}"
S=snapshot

[ -f "$S/deployments.yaml" ] || { echo "run 00-snapshot.sh first"; exit 1; }

echo ">> Target context: $NEW"
kubectl --context "$NEW" apply -f "$S/clusterrolebinding.yaml" 2>/dev/null || true
kubectl --context "$NEW" -n default apply -f "$S/configmaps.yaml"
kubectl --context "$NEW" -n default apply -f "$S/secrets.yaml"
kubectl --context "$NEW" -n default apply -f "$S/services.yaml"
kubectl --context "$NEW" -n default apply -f "$S/deployments.yaml"

echo
echo ">> Waiting for deployments to roll out"
for d in camp-newapi-app coderprabhu-api-app coderprabhu-ui-web menu-api-app \
         menu-ui-web new-camp-ui-web rentalapi-app rentalui-web; do
  kubectl --context "$NEW" -n default rollout status deploy/"$d" --timeout=180s || \
    echo "   WARN: $d not ready — check 'kubectl --context $NEW -n default describe deploy $d'"
done

echo
kubectl --context "$NEW" -n default get pods -o wide
kubectl --context "$NEW" -n default get endpoints
echo
echo ">> If all Ready with endpoints, next: migration/30-deploy-gateway.sh"
