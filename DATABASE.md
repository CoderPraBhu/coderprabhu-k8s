# Commands:  

Run mongo DB Local: 
```
mongod --config /usr/local/etc/mongod.conf
```
Log into Mongo DB pod in production: 
```
kubectl exec -it mongo-0 -c mongo bash
db.visitor.remove({ip: "73.70.114.eknausaha"})
```

Install Mongo DB on local
```
brew tap mongodb/brew
brew install mongodb-community@4.2
To have launchd start mongodb/brew/mongodb-community now and restart at login:
 brew services start mongodb/brew/mongodb-community
Or, if you don't want/need a background service you can just run:
  mongod --config /usr/local/etc/mongod.conf
```
