This repository holds k8s manifests for https://coderprabhu.com

Git Repo for UI: https://github.com/CoderPraBhu/coderprabhu-ui  
Git Repo for API: https://github.com/CoderPraBhu/coderprabhu-api  
This Repo for K8S: https://github.com/CoderPraBhu/coderprabhu-k8s  

## Commands:  

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
gcloud container clusters delete "hello-world"
kubectl apply -f coderprabhu-mongo-headlessservice.yaml
kubectl get service mongo
kubectl describe service mongo
kubectl apply -f coderprabhu-mongo-statefulset.yaml
kubectl delete -f coderprabhu-mongo-statefulset.yaml
kubectl get statefulset
kubectl get statefulset mongo
kubectl describe statefulset mongo
kubectl exec -ti mongo-0 mongo
rs.conf()
```
# HTTPS redirection: *In Progress* 
Wait for fix from GKE: https://github.com/kubernetes/ingress-gce/issues/1075
```
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
#Additional commands:  
```
kubectl apply -f coderprabhu-cluster-role-binding.yaml
gcloud container clusters create coderprabhu-cluster    
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
```