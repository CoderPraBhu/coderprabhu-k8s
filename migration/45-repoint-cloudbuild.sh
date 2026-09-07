#!/usr/bin/env bash
# Repoint Cloud Build so future app deploys land on allprojects-v2, not the
# deleted allprojects-cluster. Run after cutover; safe to run before.
#
# Two mechanisms are in play:
#   1. Repos with an in-tree cloudbuild.yaml whose _GKE_CLUSTER default = the
#      cluster  -> fixed on branch `deploy-to-allprojects-v2` in each repo
#      (campui, rentalapi, rentalui, coderprabhu-api). MERGE + PUSH those.
#   2. Triggers that override _GKE_CLUSTER inline (no repo file) -> this script.
set -euo pipefail

# `gcloud builds triggers update` needs the trigger TYPE subcommand and, for
# GitHub triggers, the repo owner/name.
echo ">> automated-deployment-4 (campapi)"
gcloud builds triggers update github automated-deployment-4 \
  --repo-owner=sanskruti29 --repo-name=campapi \
  --update-substitutions=_GKE_CLUSTER=allprojects-v2

echo ">> automated-deployment-1 (whatsgoodonmenuui)"
gcloud builds triggers update github automated-deployment-1 \
  --repo-owner=sanskruti29 --repo-name=whatsgoodonmenuui \
  --update-substitutions=_GKE_CLUSTER=allprojects-v2

echo ">> automated-deployment-3 (coderprabhu-ui, mirrored repo)"
gcloud builds triggers update cloud-source-repositories automated-deployment-3 \
  --update-substitutions=_GKE_CLUSTER=allprojects-v2

echo
echo ">> Verify:"
gcloud builds triggers list \
  --format="table(name, substitutions._GKE_CLUSTER)" \
  --filter="substitutions._GKE_CLUSTER:*"
echo
echo ">> Still TODO by hand:"
echo "   - Merge + push branch deploy-to-allprojects-v2 in: campui, rentalapi, rentalui, coderprabhu-api"
echo "   - campui trigger (automated-deployment-2) and push-to-rental-* use the repo"
echo "     file default, so the merge above covers them — no trigger edit needed."
echo "   - coderprabhu-api & menu-api: deploy manually against the allprojects-v2 context."
