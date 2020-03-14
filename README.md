This repository holds k8s manifests for https://coderprabhu.com

Git Repo for UI: https://github.com/CoderPraBhu/coderprabhu-ui  
Git Repo for API: https://github.com/CoderPraBhu/coderprabhu-api  
This Repo for K8S: https://github.com/CoderPraBhu/coderprabhu-k8s  

Commands:  

To update the k8s deployment with new version, update the api deployment yaml with new 
container image versions and execute
````
kubectl apply -f coderprabhu-api-deployment.yaml  
kubectl apply -f coderprabhu-ui-deployment.yaml  
kubectl apply -f coderprabhu-ui-dot-com-cert.yaml  
kubectl apply -f coderprabhu-api-dot-com-cert.yaml  
kubectl apply -f coderprabhu-ingress.yaml  
````
Curl commands:   
````
curl http://coderprabhu.com
curl https://coderprabhu.com
curl http://www.coderprabhu.com
curl https://www.coderprabhu.com
curl http://api.coderprabhu.com
curl https://api.coderprabhu.com
curl https://api.coderprabhu.com/actuator/info
curl https://api.coderprabhu.com/actuator/health
````   
Additional commands:  
```
gcloud container clusters create coderprabhu-cluster    
gcloud compute addresses create coderprabhu-ip --global
  
gcloud compute addresses describe coderprabhu-ip --global
kubectl get ingress
kubectl get ingress coderprabhu-ingress --output yaml
kubectl get deployment coderprabhu-ui-web
kubectl get deployment coderprabhu-api-app
```