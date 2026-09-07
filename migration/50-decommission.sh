#!/usr/bin/env bash
# Final teardown. Run only after 40-cutover-keep-ip.sh reported CUTOVER COMPLETE
# and allprojects-v2 has served prod on 34.98.91.174 without issues for a while.
set -euo pipefail
OLD="${OLD_CONTEXT:-allprojects-cluster}"
PROJECT=all-projects-292200
ZONE=us-west1-b

read -rp "allprojects-v2 has served prod OK on 34.98.91.174? [type YES] " ok
[ "$ok" = YES ] || { echo aborted; exit 1; }

echo ">> Deleting old ManagedCertificates"
kubectl --context "$OLD" delete managedcertificate --all -n default --ignore-not-found

echo ">> Deleting old cluster allprojects-cluster"
gcloud container clusters delete allprojects-cluster --zone="$ZONE" --project="$PROJECT" --quiet

echo ">> Releasing the temp Gateway IP (allprojects-gw-ip / 136.68.8.150)"
gcloud compute addresses delete allprojects-gw-ip --global --project="$PROJECT" --quiet

echo
echo ">> Done. Follow-ups:"
echo "   - Repoint each app's Cloud Build deploy trigger to allprojects-v2"
echo "     (coderprabhu-ui, campui, campapi, whatsgoodonmenuui, rentalui, rentalapi)."
echo "   - Deploy coderprabhu-api / menu-api against the allprojects-v2 context from now on."
echo "   - Update CLAUDE.md + README.md (cluster name allprojects-v2)."
echo "   - Keep allprojects-ingress-ssl-policy (used by GCPGatewayPolicy)."
