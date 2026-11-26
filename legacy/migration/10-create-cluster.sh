#!/usr/bin/env bash
# Create allprojects-v2: VPC-native replacement for allprojects-cluster.
# Matches the old cluster (zone, machine type, RAPID channel) but adds
# --enable-ip-alias (VPC-native) so GKE Gateway NEGs work, and enables the
# modern Gateway API. Pod/Service ranges are chosen to NOT overlap the old
# routes-based cluster (pods 10.0.0.0/14, services 10.3.240.0/20) so both
# clusters can run in parallel during the cutover.
set -euo pipefail

PROJECT=all-projects-292200
ZONE=us-west1-b
NAME=allprojects-v2

gcloud container clusters create "$NAME" \
  --project="$PROJECT" \
  --zone="$ZONE" \
  --release-channel=rapid \
  --enable-ip-alias \
  --network=default \
  --subnetwork=default \
  --cluster-ipv4-cidr=10.100.0.0/14 \
  --services-ipv4-cidr=10.104.0.0/20 \
  --num-nodes=1 \
  --machine-type=e2-custom-2-3072 \
  --disk-type=pd-standard \
  --disk-size=50 \
  --gateway-api=standard \
  --addons=HttpLoadBalancing,GcePersistentDiskCsiDriver \
  --no-enable-basic-auth \
  --no-issue-client-certificate

gcloud container clusters get-credentials "$NAME" --zone="$ZONE" --project="$PROJECT"
kubectl config rename-context "gke_${PROJECT}_${ZONE}_${NAME}" "$NAME" 2>/dev/null || true

echo
kubectl --context "$NAME" get nodes
kubectl --context "$NAME" get gatewayclass
echo
echo ">> allprojects-v2 ready. Next: migration/20-restore-workloads.sh"
