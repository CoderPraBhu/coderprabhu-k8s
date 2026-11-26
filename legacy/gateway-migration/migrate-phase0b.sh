#!/usr/bin/env bash
# Phase 0b — remove the deprecated 2021 v1alpha1 Gateway API preview CRDs.
# GKE's Gateway controller will not register the modern GatewayClasses
# (gke-l7-global-external-managed, etc.) while the old preview install is present.
# Verified safe: no Gateway/Route resources use these CRDs (only the two
# auto-created legacy GatewayClasses exist). See docs/gateway-api-migration.md.
set -euo pipefail

echo ">> Deleting deprecated *.networking.x-k8s.io Gateway CRDs"
kubectl delete crd \
  gatewayclasses.networking.x-k8s.io \
  gateways.networking.x-k8s.io \
  httproutes.networking.x-k8s.io \
  tcproutes.networking.x-k8s.io \
  tlsroutes.networking.x-k8s.io \
  udproutes.networking.x-k8s.io \
  backendpolicies.networking.x-k8s.io \
  gatewaystates.networking.gke.io

echo ">> Waiting for GKE to register the modern GatewayClasses (up to ~5 min)"
for i in $(seq 1 30); do
  if kubectl get gatewayclass gke-l7-global-external-managed >/dev/null 2>&1; then
    break
  fi
  sleep 10
done

echo ">> GatewayClasses now:"
kubectl get gatewayclass
