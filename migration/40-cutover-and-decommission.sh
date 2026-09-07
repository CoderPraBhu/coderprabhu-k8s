#!/usr/bin/env bash
# Run AFTER 30-deploy-gateway.sh is all-green AND after you have repointed every
# A record from 34.98.91.174 -> 136.68.8.150 and verified traffic on the new
# Gateway for a while. This tears down the old cluster.
set -euo pipefail
OLD="${OLD_CONTEXT:-allprojects-cluster}"
PROJECT=all-projects-292200
ZONE=us-west1-b

read -rp "Confirming: DNS is on 136.68.8.150 and the new Gateway has served prod OK? [type YES] " ok
[ "$ok" = YES ] || { echo "aborted"; exit 1; }

echo ">> Deleting old Ingress + FrontendConfig + ManagedCertificates (old cluster)"
kubectl --context "$OLD" delete -f allprojects-ingress.yaml --ignore-not-found
kubectl --context "$OLD" delete -f allprojects-ingress-security-config.yaml --ignore-not-found
kubectl --context "$OLD" delete managedcertificate --all -n default --ignore-not-found

echo ">> Deleting old cluster: allprojects-cluster"
gcloud container clusters delete allprojects-cluster --zone="$ZONE" --project="$PROJECT" --quiet

echo ">> Releasing the old static IP (allprojects-ip / 34.98.91.174)"
gcloud compute addresses delete allprojects-ip --global --project="$PROJECT" --quiet

echo
echo ">> Done. Keep allprojects-ingress-ssl-policy (used by GCPGatewayPolicy)."
echo ">> Remaining manual step: repoint each app's Cloud Build deploy trigger"
echo "   (_GKE_CLUSTER / gke-deploy target) from allprojects-cluster -> allprojects-v2."
