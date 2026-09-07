#!/usr/bin/env bash
# Phase 0 — prerequisites for the Gateway API + Certificate Manager migration.
# Non-disruptive: does not touch the running Ingress or any workload.
# See docs/gateway-api-migration.md.
set -euo pipefail

ACCOUNT="prashantbhuruk88@gmail.com"
PROJECT="all-projects-292200"
CLUSTER="allprojects-cluster"
ZONE="us-west1-b"

echo ">> Setting gcloud context ($ACCOUNT / $PROJECT)"
gcloud config set account "$ACCOUNT"
gcloud config set project "$PROJECT"
gcloud container clusters get-credentials "$CLUSTER" --zone "$ZONE"

echo ">> Enabling Certificate Manager API"
gcloud services enable certificatemanager.googleapis.com

echo ">> Enabling modern GA Gateway API on the cluster (control-plane update, ~2-5 min)"
gcloud container clusters update "$CLUSTER" --zone "$ZONE" --gateway-api=standard

echo ">> Verifying"
kubectl get gatewayclass
echo
kubectl get crd gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io

echo
echo ">> Phase 0 done. Expect to see GatewayClass 'gke-l7-global-external-managed'."
