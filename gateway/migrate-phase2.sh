#!/usr/bin/env bash
# Phase 2 — reserve the Gateway's static IP. Non-disruptive.
set -euo pipefail

if gcloud compute addresses describe allprojects-gw-ip --global >/dev/null 2>&1; then
  echo "allprojects-gw-ip already reserved."
else
  gcloud compute addresses create allprojects-gw-ip --global --ip-version=IPV4
fi

IP=$(gcloud compute addresses describe allprojects-gw-ip --global --format='value(address)')
echo
echo "allprojects-gw-ip = $IP"
echo "(current Ingress IP allprojects-ip = 34.98.91.174 — unchanged)"
