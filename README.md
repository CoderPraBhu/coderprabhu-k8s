This repository holds code and configurations for https://coderprabhu.com

Git Repo: https://github.com/CoderPraBhu/coderprabhu

UI App:
```
npx create-react-app coderprabhu-ui
````

Udpate commands:  
```gcloud container clusters create coderprabhu-cluster  
docker build -t gcr.io/kubegcp-256806/coderprabhu-ui:v1 .  
docker run --rm -p 8080:8080 gcr.io/kubegcp-256806/coderprabhu-ui:v1  
docker push gcr.io/kubegcp-256806/coderprabhu-ui:v1  
kubectl apply -f manifests/coderprabhu-ui-deployment.yaml  
gcloud compute addresses create coderprabhu-ip --global  
kubectl apply -f manifests/coderprabhu-ingress-static-ip.yaml  
```
Read commands:   
```
curl http://coderprabhu.com
curl https://coderprabhu.com
curl http://www.coderprabhu.com
curl https://www.coderprabhu.com
curl http://api.coderprabhu.com
curl https://api.coderprabhu.com
```   