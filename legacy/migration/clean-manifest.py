#!/usr/bin/env python3
"""Strip cluster-specific fields from `kubectl get -o yaml` output so the
manifests apply cleanly to a fresh cluster. Reads multi-doc YAML on stdin."""
import sys, yaml

DROP_META = {"resourceVersion", "uid", "creationTimestamp", "generation",
             "managedFields", "selfLink", "ownerReferences"}
DROP_ANN = {"kubectl.kubernetes.io/last-applied-configuration",
            "deployment.kubernetes.io/revision",
            "autopilot.gke.io/resource-adjustment",
            "cloud.google.com/neg-status"}

def clean(obj):
    if not isinstance(obj, dict):
        return obj
    obj.pop("status", None)
    m = obj.get("metadata", {})
    for k in list(m):
        if k in DROP_META:
            m.pop(k)
    ann = m.get("annotations", {})
    for k in list(ann):
        if k in DROP_ANN:
            ann.pop(k)
    if ann == {}:
        m.pop("annotations", None)
    spec = obj.get("spec", {})
    if obj.get("kind") == "Service":
        for k in ("clusterIP", "clusterIPs", "ipFamilies", "ipFamilyPolicy",
                  "internalTrafficPolicy", "sessionAffinity"):
            spec.pop(k, None)
        for p in spec.get("ports", []):
            p.pop("nodePort", None)
    return obj

docs = [clean(d) for d in yaml.safe_load_all(sys.stdin) if d]
yaml.safe_dump_all(docs, sys.stdout, default_flow_style=False, sort_keys=False)
