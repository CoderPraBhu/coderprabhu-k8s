#!/usr/bin/env bash
# Snapshot the current allprojects-cluster workload state to migration/snapshot/.
# Read-only against the cluster. Output contains Secrets -> gitignored, do not commit.
set -euo pipefail
cd "$(dirname "$0")"
OUT="snapshot"
CTX="${OLD_CONTEXT:-$(kubectl config current-context)}"
mkdir -p "$OUT"

echo ">> Snapshotting from context: $CTX"

# App workloads (deployed by Cloud Build, not in this repo) + their config.
DEPLOYS="camp-newapi-app coderprabhu-api-app coderprabhu-ui-web menu-api-app menu-ui-web new-camp-ui-web rentalapi-app rentalui-web"
SVCS="camp-newapi-backend coderprabhu-api-backend coderprabhu-ui-backend menu-api-backend menu-ui-backend new-camp-ui-backend rentalapi-backend rentalui-backend rentalui-car-rental rentalui-gym rentalui-homepage rentalui-hospitality rentalui-jewelry rentalui-real-estate"
CMS="camp-newapi-config coderprabhu-api-log-level mongodb-atlas-config rentalapi-config"
SECRETS="gmail-secret mongo-db-user-pass mongodb-atlas-secret rentalapi-gcs-key rentalapi-google-maps-secret rentalapi-jwt-secret rentalapi-session-secret session-secret"

dump() {  # kind, space-separated names, filename
  local kind="$1" names="$2" file="$3"
  : > "$OUT/$file"
  for n in $names; do
    kubectl --context "$CTX" -n default get "$kind" "$n" -o yaml >> "$OUT/$file.raw" 2>/dev/null \
      && echo "---" >> "$OUT/$file.raw" \
      || echo "   WARN: $kind/$n not found"
  done
  python3 clean-manifest.py < "$OUT/$file.raw" > "$OUT/$file"
  rm -f "$OUT/$file.raw"
  echo "   wrote $OUT/$file"
}

dump configmap "$CMS"     configmaps.yaml
dump secret    "$SECRETS" secrets.yaml
dump deployment "$DEPLOYS" deployments.yaml
dump service   "$SVCS"    services.yaml

kubectl --context "$CTX" get clusterrolebinding default-view -o yaml 2>/dev/null \
  | python3 clean-manifest.py > "$OUT/clusterrolebinding.yaml" || true

echo
echo ">> Snapshot complete in migration/$OUT/ (gitignored). Images referenced:"
grep -h 'image:' "$OUT/deployments.yaml" | sed 's/^/   /'
