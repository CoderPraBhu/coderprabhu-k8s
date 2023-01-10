# Commands:  

Run mongo DB Local: 
```
mongod --config /usr/local/etc/mongod.conf
```
Add Mongod in path either directly on shell or adding to ~/.zshrc or ~/.bash_profile
```
export PATH=$PATH:/usr/local/opt/mongodb-community/bin
```
Log into Mongo DB pod in production: 
```
kubectl exec -it mongo-0 -c mongo bash
mongo
show databases 
use CoderPraBhuApi
show collections
db.visitor.find()
db.visitor.remove({ip: "73.70.114.196"})

```

Install Mongo DB on local
```
brew tap mongodb/brew
brew install mongodb-community@4.2
To have launchd start mongodb/brew/mongodb-community now and restart at login:
 brew services start mongodb/brew/mongodb-community
Or, if you don't want/need a background service you can just run:
  mongod --config /usr/local/etc/mongod.conf
brew info mongodb-community
```
