This repository holds k8s manifests for 
* https://coderprabhu.com
* https://tornacampsites.com
* https://whatsgoodonmenu.com 

> **Sep 2026:** the `allprojects` apps now run on **`allprojects-v2`** (VPC-native GKE
> cluster) behind a **GKE Gateway** + **Certificate Manager** cert map, not the old
> `allprojects-cluster` / Ingress. Static IP `allprojects-ip` (34.98.91.174) is unchanged.
> Full runbook + history: [`docs/gateway-api-migration.md`](docs/gateway-api-migration.md).
> Manifests: [`gateway/`](gateway/). Rebuild scripts: [`migration/`](migration/).
> `coderprabhu-cluster` is unchanged.

Git Repo for CoderPraBhu.com UI: https://github.com/CoderPraBhu/coderprabhu-ui  
Git Repo for CoderPraBhu.com API: https://github.com/CoderPraBhu/coderprabhu-api  
This Repo for K8S: https://github.com/CoderPraBhu/coderprabhu-k8s  

# Commands:  

When code is updated update the ui and api deployment yaml with new 
container image versions.
To create or update the k8s deployment
```
kubectl apply -f coderprabhu-api-deployment.yaml  
kubectl apply -f coderprabhu-ui-deployment.yaml  
kubectl apply -f coderprabhu-api-backend-service.yaml  
kubectl apply -f coderprabhu-ui-backend-service.yaml  
kubectl apply -f coderprabhu-ingress.yaml 
```
https://cloud.google.com/kubernetes-engine/docs/how-to/stateless-apps
# Curl commands:   
```
curl http://coderprabhu.com
curl https://coderprabhu.com
curl http://www.coderprabhu.com
curl https://www.coderprabhu.com
curl http://api.coderprabhu.com
curl https://api.coderprabhu.com
curl http://api.coderprabhu.com/hello
curl https://api.coderprabhu.com/hello
curl http://api.coderprabhu.com/count
curl https://api.coderprabhu.com/count
curl https://api.coderprabhu.com/actuator/info
curl https://api.coderprabhu.com/actuator/health
```   
# Google Managed Certs:
https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs  
https://cloud.google.com/kubernetes-engine/docs/how-to/managed-certs  
https://cloud.google.com/load-balancing/docs/quotas#ssl_certificates  
```
kubectl apply -f coderprabhu-ui-dot-com-cert.yaml  
kubectl apply -f coderprabhu-api-dot-com-cert.yaml  
kubectl apply -f coderprabhu-www-dot-com-cert.yaml
gcloud beta compute ssl-certificates list --global  
```
# Remove k8s objects
```
kubectl delete -f coderprabhu-ingress.yaml 
kubectl delete -f coderprabhu-api-backend-service.yaml  
kubectl delete -f coderprabhu-ui-backend-service.yaml  
kubectl delete -f coderprabhu-api-deployment.yaml  
kubectl delete -f coderprabhu-ui-deployment.yaml  
```
# Storage:  
https://kubernetes.io/blog/2017/01/running-mongodb-on-kubernetes-with-statefulsets/
https://cloud.google.com/kubernetes-engine/docs/concepts/persistent-volumes
https://cloud.google.com/kubernetes-engine/docs/concepts/statefulset
https://cloud.google.com/kubernetes-engine/docs/how-to/stateful-apps
```
kubectl apply -f coderprabhu-storage-class-hdd.yaml
kubectl get storageclass
kubectl get storageclass coderprabhu-storage-class-hdd
kubectl get storageclass standard
kubectl describe storageclass coderprabhu-storage-class-hdd
kubectl describe storageclass standard
kubectl delete statefulset mongo
kubectl delete svc mongo
kubectl delete pvc -l role=mongo
Note: To help prevent data loss, PersistentVolumes and PersistentVolumeClaims are not deleted when a StatefulSet is deleted. You must manually delete these objects using kubectl delete pv and kubectl delete pvc.
gcloud container clusters delete "hello-world"
kubectl apply -f coderprabhu-mongo-headlessservice.yaml
kubectl get service mongo
kubectl describe service mongo
kubectl apply -f coderprabhu-mongo-statefulset.yaml
kubectl rollout history statefulset mongo
kubectl delete -f coderprabhu-mongo-statefulset.yaml
kubectl get statefulset
kubectl get statefulset mongo
kubectl describe statefulset mongo
kubectl get pv
kubectl describe pv pvc-1d3300d2-7d24-11ea-bcdc-42010a8a0158
kubectl describe pv pvc-3ce3fb0b-7d19-11ea-bcdc-42010a8a0158
kubectl get pvc
kubectl describe pv 
kubectl describe pvc mongo-persistent-storage-mongo-0
kubectl describe pvc mongo-persistent-storage-mongo-1
kubectl exec -ti mongo-0 mongo
kubectl exec -it mongo-0 -c mongo -- /bin/bash
kubectl exec -it mongo-0 -c mongo -- ls -la /data/db
kubectl exec -it mongo-0 -c mongo -- ls -la /data/db
kubectl exec mongo-0 -c mongo -i -t -- bash -
kubectl exec mongo-0 -c mongo -i -t -- ls -t /usr
kubectl exec mongo-0 -c mongo -i -t -- mongo
rs.conf()
rs.status()
rs.isMaster()
rs.slaveOk()
rs.secondaryOk()
Note: rs.initiate() on the node otherwise you will get following error: 
        "errmsg" : "node is not in primary or recovering state",
        "code" : 13436,

```
# HTTPS redirection: *In Progress* 
Wait for fix from GKE: https://github.com/kubernetes/ingress-gce/issues/1075

https://github.com/GoogleCloudPlatform/gke-networking-recipes/blob/master/ingress/secure-ingress/secure-ingress.yaml
```

gcloud compute ssl-policies create allprojects-ingress-ssl-policy  --profile MODERN --min-tls-version 1.2
kubectl apply -f allprojects-ingress-security-config.yaml
kubectl get -f allprojects-ingress-security-config.yaml
kubectl describe -f allprojects-ingress-security-config.yaml

==> gcloud compute url-maps import coderprabhu-web-map-http --source coderprabhu-web-map-http.yaml --global  
gcloud compute url-maps describe coderprabhu-web-map-http
gcloud compute target-http-proxies list
   k8s-tp-default-coderprabhu-ingress--de7ff4b20a1828c3  k8s-um-default-coderprabhu-ingress--de7ff4b20a1828c3
gcloud compute target-http-proxies describe k8s-tp-default-coderprabhu-ingress--de7ff4b20a1828c3
gcloud compute url-maps describe k8s-um-default-coderprabhu-ingress--de7ff4b20a1828c3
==> gcloud compute target-http-proxies create coderprabhu-http-lb-proxy --url-map=coderprabhu-web-map-http --global
gcloud compute target-http-proxies update coderprabhu-http-lb-proxy --url-map=coderprabhu-web-map-http --global   
gcloud compute target-http-proxies describe coderprabhu-http-lb-proxy
gcloud compute forwarding-rules list 
gcloud compute forwarding-rules describe k8s-fw-default-coderprabhu-ingress--de7ff4b20a1828c3 --global
gcloud compute forwarding-rules describe k8s-fws-default-coderprabhu-ingress--de7ff4b20a1828c3 --global
gcloud compute forwarding-rules describe coderprabhu-http-content-rule --global 
gcloud compute forwarding-rules create coderprabhu-http-content-rule --address=coderprabhu-ip --global --target-http-proxy=coderprabhu-http-lb-proxy --ports=80
gcloud compute forwarding-rules update k8s-fw-default-coderprabhu-ingress--de7ff4b20a1828c3  --target=k8s-tp-default-coderprabhu-ingress--de7ff4b20a1828c3
==> No such command exists. So modified rule from Gcloud console
gcloud compute forwarding-rules update k8s-fw-default-coderprabhu-ingress--de7ff4b20a1828c3  --target=coderprabhu-http-lb-proxy
```
# Additional commands:  
```
kubectl apply -f coderprabhu-cluster-role-binding.yaml
gcloud container clusters create coderprabhu-cluster    
gcloud container clusters get-credentials coderprabhu-cluster
gcloud compute addresses create coderprabhu-ip --global  
gcloud compute addresses describe coderprabhu-ip --global
gcloud compute addresses describe coderprabhu-ip --format="get(address)" --global
kubectl get ingress
kubectl describe ingress coderprabhu-ingress
kubectl get ingress coderprabhu-ingress --output yaml
kubectl get deployment coderprabhu-ui-web
kubectl describe deployment coderprabhu-ui-web
kubectl get deployment coderprabhu-api-app
kubectl get service coderprabhu-api-backend
kubectl get service coderprabhu-ui-backend
kubectl describe service coderprabhu-api-backend
kubectl describe service coderprabhu-ui-backend
gcloud compute forwarding-rules list
gcloud compute forwarding-rules describe k8s-fw-default-coderprabhu-ingress--de7ff4b20a1828c3 --global
gcloud compute target-http-proxies list
gcloud compute target-https-proxies list
gcloud compute target-http-proxies describe k8s-tp-default-coderprabhu-ingress--de7ff4b20a1828c3
gcloud compute url-maps list
gcloud compute url-maps describe k8s-um-default-coderprabhu-ingress--de7ff4b20a1828c3
kubectl scale deployment coderprabhu-api-app --replicas=0 
```

# Changing machine type for node pool:
https://cloud.google.com/kubernetes-engine/docs/tutorials/migrating-node-pool
```
gcloud container node-pools list --cluster coderprabhu-cluster
gcloud container node-pools create coderprabhu-e2-small-pool 
--cluster=coderprabhu-cluster --machine-type=e2-small --num-nodes=1
kubectl get nodes
kubectl get pods -o=wide
kubectl get nodes -l cloud.google.com/gke-nodepool=coderprabhu-g1-small-pool
kubectl cordon gke-coderprabhu-clus-coderprabhu-g1-s-9fee5f72-0c0d
kubectl get nodes => scheduling disabled 
kubectl drain --force --ignore-daemonsets --delete-local-data --grace-period=10 gke-coderprabhu-clus-coderprabhu-g1-s-9fee5f72-0c0d
gcloud container node-pools delete coderprabhu-g1-small-pool --cluster coderprabhu-cluster


gcloud container node-pools create coderprabhu-e2-medium-pool --cluster=coderprabhu-cluster --machine-type=e2-medium --num-nodes=1
kubectl get nodes
kubectl get pods -o=wide
kubectl get nodes -l cloud.google.com/gke-nodepool=coderprabhu-e2-small-pool 
kubectl cordon gke-coderprabhu-clus-coderprabhu-e2-s-b112d31a-x845
kubectl drain --force --ignore-daemonsets --delete-local-data --grace-period=10 gke-coderprabhu-clus-coderprabhu-e2-s-b112d31a-x845
gcloud container node-pools delete coderprabhu-e2-small-pool --cluster coderprabhu-cluster


gcloud container node-pools list --cluster allprojects-cluster
kubectl get nodes
gcloud container node-pools create allprojects-e2-medium-pool --cluster=allprojects-cluster --machine-type=e2-medium --num-nodes=1
kubectl get nodes -l cloud.google.com/gke-nodepool=allprojects-e2-medium-pool

kubectl cordon gke-allprojects-cluster-default-pool-fd4d2849-chlg
kubectl cordon gke-allprojects-cluster-default-pool-fd4d2849-p3p7
kubectl cordon gke-allprojects-cluster-default-pool-fd4d2849-v2cb

gke-allprojects-cluster-default-pool-fd4d2849-chlg   Ready    <none>   7d23h   v1.16.13-gke.401
gke-allprojects-cluster-default-pool-fd4d2849-p3p7   Ready    <none>   7d23h   v1.16.13-gke.401
gke-allprojects-cluster-default-pool-fd4d2849-v2cb   Ready    <none>   7d23h   v1.16.13-gke.401

kubectl drain --force --ignore-daemonsets --delete-local-data --grace-period=10 gke-allprojects-cluster-default-pool-fd4d2849-chlg 
kubectl drain --force --ignore-daemonsets --delete-local-data --grace-period=10 gke-allprojects-cluster-default-pool-fd4d2849-p3p7
kubectl drain --force --ignore-daemonsets --delete-local-data --grace-period=10 gke-allprojects-cluster-default-pool-fd4d2849-v2cb 

gcloud container node-pools delete default-pool --cluster allprojects-cluster

```


## Clean Slate:
```
Check authentication: 
gcloud auth list


To set the active account, run:

Switch to new account: 
gcloud config set account prashantbhuruk88@gmail.com
gcloud config set project all-projects-292200
gcloud container clusters get-credentials allprojects-v2 --zone us-west1-b
# (was: sanskruti2489@gmail.com / allprojects-cluster, retired Sep 2026)

Switch to old account: 
gcloud config set account skolpe@mail.ccsf.edu
gcloud config set project kubegcp-256806
gcloud container clusters get-credentials coderprabhu-cluster --zone us-west1-b

gcloud container clusters get-credentials allprojects-cluster --zone us-west1-b	 --project all-projects-292200	

gcloud auth login

To show current config/references:
gcloud config list

gcloud container clusters list

gcloud container clusters create allprojects-cluster
gcloud container clusters get-credentials allprojects-cluster

gcloud compute addresses create allprojects-ip --global  
gcloud compute addresses describe allprojects-ip --global       old=35.201.92.92    new=34.98.91.174 
gcloud compute addresses describe allprojects-ip --format="get(address)" --global

gcloud auth configure-docker

kubectl apply -f allprojects-ingress.yaml 
kubectl get ingress
kubectl describe ingress allprojects-ingress

kubectl apply -f allprojects-storage-class-hdd.yaml
kubectl get storageclass
kubectl get storageclass allprojects-storage-class-hdd
kubectl get storageclass standard
kubectl describe storageclass allprojects-storage-class-hdd
kubectl describe storageclass standard
kubectl delete statefulset mongo
kubectl delete svc mongo
kubectl delete pvc -l role=mongo
Note: To help prevent data loss, PersistentVolumes and PersistentVolumeClaims are not deleted when a StatefulSet is deleted. You must manually delete these objects using kubectl delete pv and kubectl delete pvc.
gcloud container clusters delete "hello-world"
kubectl apply -f allprojects-mongo-headlessservice.yaml
kubectl get service mongo
kubectl describe service mongo
kubectl apply -f allprojects-mongo-statefulset.yaml
kubectl rollout history statefulset mongo
kubectl delete -f allprojects-mongo-statefulset.yaml
kubectl get statefulset
kubectl get statefulset mongo
kubectl describe statefulset mongo
kubectl exec -it mongo-0 -c mongo -- /bin/bash

```
# Backup and restore: 
```
Log in to container and run: 
mongodump 

Logout and copy the files from default dump folder to a local folder 
kubectl cp mongo-0:dump /Users/Sanskruti/react/mongobkp

Change to target cluster: 

kubectl cp /Users/Sanskruti/react/mongobkp mongo-0:dumpfrom 
cd to the folder 
cd dumpfrom 
mongorestore -d MenuApi /dumpfrom/mongobkp/MenuApi 
mongorestore -d CoderPraBhuApi /dumpfrom/mongobkp/CoderPraBhuApi 
mongorestore -d campdb /dumpfrom/mongobkp/campdb 
```

Upgrade a cluster
```

coderprabhu@PraBhuMBP ~ % gcloud container clusters list

```

K8S Dockershim Deprecation 
https://www.protocol.com/enterprise/kubernetes-dockershim-containers-cri-runtime


https://console.cloud.google.com/home/recommendations/view-link/projects/190440084777/locations/us-west1-b/recommenders/google.container.DiagnosisRecommender/recommendations/d4cf3559-f294-42e8-a2a9-61a42b32c935

Following tool does not work with Mac. Needs linux. Commands for reference only 
```
https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/

crictl -version
critest -version
crictl pods
crictl pods --name nginx-65899c769f-wv2gp
crictl pods --label run=nginx
crictl images
crictl images nginx
crictl images -q
crictl ps -a
crictl ps
crictl exec -i -t 1f73f2d81bf98 ls
crictl logs 87d3992f84f74
crictl logs --tail=1 87d3992f84f74
crictl runp pod-config.json
{
  "metadata": {
    "name": "nginx-sandbox",
    "namespace": "default",
    "attempt": 1,
    "uid": "hdishd83djaidwnduwk28bcsb"
  },
  "log_directory": "/tmp",
  "linux": {
  }
}
crictl pull busybox
Pod config:
{
  "metadata": {
    "name": "busybox-sandbox",
    "namespace": "default",
    "attempt": 1,
    "uid": "aewi4aeThua7ooShohbo1phoj"
  },
  "log_directory": "/tmp",
  "linux": {
  }
}
Container config:
{
  "metadata": {
    "name": "busybox"
  },
  "image":{
    "image": "busybox"
  },
  "command": [
    "top"
  ],
  "log_path":"busybox.log",
  "linux": {
  }
}
crictl create f84dd361f8dc51518ed291fbadd6db537b0496536c1d2d6c05ff943ce8c9a54f container-config.json pod-config.json
crictl ps -a

```

Install crictl

```

brew install wget
brew link --overwrite wget
wget --version

VERSION="v1.26.0"
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-darwin-amd64.tar.gz

sudo tar zxvf crictl-$VERSION-darwin-amd64.tar.gz -C /usr/local/bin
rm -f crictl-$VERSION-darwin-amd64.tar.gz
```
Install critest
```
VERSION="v1.26.0"
wget http://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/critest-$VERSION-darwin-amd64.tar.gz
sudo tar zxvf critest-$VERSION-darwin-amd64.tar.gz -C /usr/local/bin
rm -f critest-$VERSION-darwin-amd64.tar.gz
```

https://cloud.google.com/kubernetes-engine/docs/how-to/migrate-containerd

```
gcloud container clusters upgrade 'allprojects-cluster' --project 'all-projects-292200' --zone 'us-west1-b' --image-type 'COS_CONTAINERD' --node-pool 'allprojects-e2-medium-pool'

coderprabhu@PraBhuMBP gke % ./find-nodepools-to-migrate.sh
ProjectId:  all-projects-292200
  Cluster: allprojects-cluster (zone: us-west1-b)
    Nodepool: allprojects-e2-medium-pool, version: 1.23.15-gke.1400 (1.23), image: COS

       Please update the nodepool to use Containerd.
       Make sure to consult with the list of known issues https://cloud.google.com/kubernetes-engine/docs/concepts/using-containerd#known_issues.
       Run the following command to upgrade:

       gcloud container clusters upgrade 'allprojects-cluster' --project 'all-projects-292200' --zone 'us-west1-b' --image-type 'COS_CONTAINERD' --node-pool 'allprojects-e2-medium-pool'

ProjectId:  jamon-coderprabhu
ProjectId:  avid-elevator-256805
ProjectId:  angular-theorem-536
ProjectId:  api-project-1026573300307
ProjectId:  api-project-52315381992


gcloud container node-pools list \
    --cluster='allprojects-cluster' \
    --format="table(name,version,config.imageType)"


```

https://stackoverflow.com/questions/51946393/kubernetes-pod-warning-1-nodes-had-volume-node-affinity-conflict
https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/volume-cloning
https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/gce-pd-csi-driver#enabling_the_on_an_existing_cluster
```

gcloud container clusters upgrade 'allprojects-cluster' --project 'all-projects-292200' --zone 'us-west1-b' --image-type 'COS_CONTAINERD' --node-pool 'allprojects-e2-medium-pool'

gcloud container clusters update 'allprojects-cluster' \
   --update-addons=GcePersistentDiskCsiDriver=ENABLED
```

# Migrate allprojects-cluster node pool: e2-medium → e2-custom-2-3072 (Feb 2026)
```
gcloud container node-pools create allprojects-e2-custom-pool \
  --cluster=allprojects-cluster \
  --machine-type=e2-custom-2-3072 \
  --num-nodes=1 \
  --zone=us-west1-b \
  --project=all-projects-292200

kubectl get nodes -l cloud.google.com/gke-nodepool=allprojects-e2-medium-pool -o name
kubectl cordon gke-allprojects-clus-allprojects-e2-m-fc8b6c4b-vb56
kubectl drain --force --ignore-daemonsets --delete-emptydir-data --grace-period=10 gke-allprojects-clus-allprojects-e2-m-fc8b6c4b-vb56
kubectl get pods -o wide
kubectl wait --for=condition=Ready pod --all --timeout=120s

gcloud container node-pools delete allprojects-e2-medium-pool \
  --cluster=allprojects-cluster \
  --zone=us-west1-b \
  --project=all-projects-292200 \
  --quiet
```

# Delete orphaned MongoDB PVC/PV and GCP disk (Feb 2026)
# MongoDB StatefulSet was removed (migrated to Atlas); PVC/PV lingered
```
kubectl get pvc,pv
kubectl delete pvc mongo-persistent-storage-mongo-0
kubectl delete pv pvc-137ccc1b-dd22-4c36-806f-0086dd65d66c
# Verify GCP disk is deleted (reclaim policy=Delete handles it automatically)
gcloud compute disks list --project=all-projects-292200 --filter="name:pvc" --format="table(name,status)"
```

# Migrate allprojects-ingress → Gateway API + Certificate Manager (Sep 2026)
Reason: hit the 15-SSL-cert limit on the ingress target proxy at 16 hostnames
(gym.tornacampsites.com stuck Provisioning). GKE Ingress can't use Certificate
Manager, so moving to a GKE Gateway + HTTPRoutes with a Certificate Manager cert
map (3 wildcard certs). Full plan + runbook: docs/gateway-api-migration.md

## Phase 0 — prerequisites (non-disruptive)
```
gcloud config set account prashantbhuruk88@gmail.com
gcloud config set project all-projects-292200
gcloud container clusters get-credentials allprojects-cluster --zone us-west1-b
gcloud services enable certificatemanager.googleapis.com
gcloud container clusters update allprojects-cluster --zone us-west1-b --gateway-api=standard
kubectl get gatewayclass
kubectl get crd gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io
# (packaged as: bash gateway/migrate-phase0.sh)
```
After --gateway-api=standard the modern CRDs installed but GatewayClasses stayed
empty ("No resources found") — the deprecated 2021 v1alpha1 preview CRDs were
still present and block the Gateway controller from registering the new classes.
Removed them (no Gateway/Route resources used them):
```
kubectl delete crd \
  gatewayclasses.networking.x-k8s.io gateways.networking.x-k8s.io \
  httproutes.networking.x-k8s.io tcproutes.networking.x-k8s.io \
  tlsroutes.networking.x-k8s.io udproutes.networking.x-k8s.io \
  backendpolicies.networking.x-k8s.io gatewaystates.networking.gke.io
kubectl get gatewayclass   # expect gke-l7-global-external-managed within ~5 min
# (packaged as: bash gateway/migrate-phase0b.sh)
```
Result: gke-l7-global-external-managed / gke-l7-regional-external-managed /
gke-l7-gxlb / gke-l7-rilb all Accepted=True.

## Phase 1 — Certificate Manager (non-disruptive)
3 wildcard certs (apex + *.apex), one DNS authorization per apex domain.
```
# 1a: cert map + DNS authorizations, then add the 3 printed CNAMEs in DNS console
gcloud certificate-manager maps create allprojects-cert-map
gcloud certificate-manager dns-authorizations create tornacampsites-dnsauth  --domain=tornacampsites.com  --type=FIXED_RECORD
gcloud certificate-manager dns-authorizations create coderprabhu-dnsauth     --domain=coderprabhu.com     --type=FIXED_RECORD
gcloud certificate-manager dns-authorizations create whatsgoodonmenu-dnsauth --domain=whatsgoodonmenu.com --type=FIXED_RECORD
gcloud certificate-manager dns-authorizations describe <name> --format="value(dnsResourceRecord.name,dnsResourceRecord.type,dnsResourceRecord.data)"
# (packaged as: bash gateway/migrate-phase1a.sh)

# --- add _acme-challenge CNAMEs in DNS console, wait for them to resolve ---

# 1b: wildcard certs + map entries (apex, *.apex) + primary entry
gcloud certificate-manager certificates create tornacampsites-wild  --domains="tornacampsites.com,*.tornacampsites.com"   --dns-authorizations=tornacampsites-dnsauth
gcloud certificate-manager certificates create coderprabhu-wild     --domains="coderprabhu.com,*.coderprabhu.com"         --dns-authorizations=coderprabhu-dnsauth
gcloud certificate-manager certificates create whatsgoodonmenu-wild --domains="whatsgoodonmenu.com,*.whatsgoodonmenu.com" --dns-authorizations=whatsgoodonmenu-dnsauth
gcloud certificate-manager maps entries create <cert>-apex     --map=allprojects-cert-map --hostname="<apex>"    --certificates=<cert>
gcloud certificate-manager maps entries create <cert>-wildcard --map=allprojects-cert-map --hostname="*.<apex>"  --certificates=<cert>
gcloud certificate-manager maps entries create default-primary --map=allprojects-cert-map --set-primary         --certificates=tornacampsites-wild
gcloud certificate-manager certificates list --format="table(name,managed.state,managed.domains)"
# (packaged as: bash gateway/migrate-phase1b.sh)
```
Result: tornacampsites-wild / coderprabhu-wild / whatsgoodonmenu-wild ACTIVE;
7 map entries ACTIVE (apex + *.apex per domain, plus default-primary).

## Phase 2 — reserve the Gateway static IP (non-disruptive)
```
gcloud compute addresses create allprojects-gw-ip --global --ip-version=IPV4
gcloud compute addresses describe allprojects-gw-ip --global --format='value(address)'
# (packaged as: bash gateway/migrate-phase2.sh)
```

## Phase 3 — deploy Gateway + HTTPRoutes alongside the Ingress (non-disruptive)
gateway/: allprojects-gateway.yaml (Gateway + GCPGatewayPolicy),
httproute-redirect.yaml, and one httproute-<domain>-<function>.yaml per
hostname/backend (route name route-<domain>-<function>).
```
kubectl apply -f gateway/
kubectl wait --for=condition=Programmed gateway/allprojects-gateway --timeout=900s
kubectl get gateway allprojects-gateway -o wide
kubectl get httproute
# then probe every hostname against the Gateway IP with curl --resolve
# (packaged as: bash gateway/migrate-phase3.sh  — applies, waits, probes all 16 hosts)
```

## Onboard a NEW apex domain later (e.g. newbrand.com)
Gateway / IP / routing policy unchanged — just a wildcard cert + 2 map entries
in allprojects-cert-map, then HTTPRoute hostnames + A records.
See docs/gateway-api-migration.md "Onboard a brand-new apex domain".
```
bash gateway/add-apex-domain.sh newbrand.com   # run 1: creates dns-auth, prints CNAME
#   -> add the _acme-challenge.newbrand.com CNAME in the DNS console (Squarespace
#      does accept the long value)
bash gateway/add-apex-domain.sh newbrand.com   # run 2: cert + map entries, wait ACTIVE
# then: add hostnames to a gateway/httproute-*.yaml, kubectl apply -f gateway/
#       add A records newbrand.com / www.newbrand.com -> allprojects-gw-ip
#       optional CAA: 0 issue "pki.goog"
```
Equivalent raw commands:
```
gcloud certificate-manager dns-authorizations create newbrand-dnsauth --domain=newbrand.com --type=FIXED_RECORD
gcloud certificate-manager dns-authorizations describe newbrand-dnsauth --format="value(dnsResourceRecord.name,dnsResourceRecord.type,dnsResourceRecord.data)"
gcloud certificate-manager certificates create newbrand-wild --domains="newbrand.com,*.newbrand.com" --dns-authorizations=newbrand-dnsauth
gcloud certificate-manager maps entries create newbrand-wild-apex     --map=allprojects-cert-map --hostname="newbrand.com"   --certificates=newbrand-wild
gcloud certificate-manager maps entries create newbrand-wild-wildcard --map=allprojects-cert-map --hostname="*.newbrand.com" --certificates=newbrand-wild
```