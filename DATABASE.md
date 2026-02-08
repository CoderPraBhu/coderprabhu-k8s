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
kubectl exec mongo-0 -it mongo-0 -c mongo -- bash
kubectl exec mongo-0 -it mongo-0 -c mongo -- bash
kubectl exec -it mongo-0 -c mongo bash
mongo
show databases 
use CoderPraBhuApi
show collections
db.visitor.find()
db.visitor.remove({ip: "73.70.114.196"})
db.visitor.remove({ip: "76.102.88.85"})
db.visitor.remove({ip: "76.102.91.44"})


db.visitor.aggregate([
    { $sortByCount: "$ip" }
]);
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

```
kubectl exec -it mongo-0 -c mongo -- mongo --eval "db.adminCommand('listDatabases')"

kubectl exec -it mongo-0 -c mongo -- mongo --eval "
var dbs = ['CoderPraBhuApi', 'CampApiDB', 'MenuApi', 'campdb'];
dbs.forEach(function(dbName) {
  print('\\n=== ' + dbName + ' ===');
  var db = db.getSiblingDB(dbName);
  db.getCollectionNames().forEach(function(col) {
    var stats = db.getCollection(col).stats();
    print(col + ': ' + stats.count + ' documents, ' + stats.size + ' bytes');
  });
});"

kubectl exec mongo-0 -c mongo -- mongo CoderPraBhuApi --eval "db.getCollectionNames().forEach(function(c) { var s = db.getCollection(c).stats(); print(c + ': ' + s.count + ' docs, ' + s.size + ' bytes'); })"

kubectl exec mongo-0 -c mongo -- mongo CampApiDB --eval "db.getCollectionNames().forEach(function(c) { var s = db.getCollection(c).stats(); print(c + ': ' + s.count + ' docs, ' + s.size + ' bytes'); })"

kubectl exec mongo-0 -c mongo -- mongo MenuApi --eval "db.getCollectionNames().forEach(function(c) { var s = db.getCollection(c).stats(); print(c + ': ' + s.count + ' docs, ' + s.size + ' bytes'); })"

kubectl exec mongo-0 -c mongo -- mongo campdb --eval "db.getCollectionNames().forEach(function(c) { var s = db.getCollection(c).stats(); print(c + ': ' + s.count + ' docs, ' + s.size + ' bytes'); })"

```


Database	Collection	Documents	Size
CoderPraBhuApi	visitor	2,340	354 KB
CampApiDB	bookings	9	1.4 KB
logins	46	3.4 KB
signups	10	1.7 KB
MenuApi	visitor	2,027	313 KB
user	3	450 B
campdb	Enquirys	5	600 B
Users	7	1.5 KB
```
kubectl exec mongo-0 -c mongo -- mongodump --archive=/data/db/full-backup.archive --gzip 2>&1
2026-01-31T20:36:39.664+0000	writing admin.system.version to archive '/data/db/full-backup.archive'
2026-01-31T20:36:39.750+0000	done dumping admin.system.version (1 document)
2026-01-31T20:36:39.752+0000	writing MenuApi.visitor to archive '/data/db/full-backup.archive'
2026-01-31T20:36:39.756+0000	writing CoderPraBhuApi.visitor to archive '/data/db/full-backup.archive'
2026-01-31T20:36:39.953+0000	writing CampApiDB.signups to archive '/data/db/full-backup.archive'
2026-01-31T20:36:39.953+0000	writing CampApiDB.logins to archive '/data/db/full-backup.archive'
2026-01-31T20:36:40.552+0000	done dumping MenuApi.visitor (2027 documents)
2026-01-31T20:36:40.552+0000	done dumping CampApiDB.signups (10 documents)
2026-01-31T20:36:40.553+0000	writing CampApiDB.bookings to archive '/data/db/full-backup.archive'
2026-01-31T20:36:40.553+0000	writing campdb.Users to archive '/data/db/full-backup.archive'
2026-01-31T20:36:40.756+0000	done dumping CampApiDB.logins (46 documents)
2026-01-31T20:36:40.848+0000	writing campdb.Enquirys to archive '/data/db/full-backup.archive'
2026-01-31T20:36:41.255+0000	done dumping campdb.Users (7 documents)
2026-01-31T20:36:41.349+0000	writing MenuApi.user to archive '/data/db/full-backup.archive'
2026-01-31T20:36:41.449+0000	done dumping CoderPraBhuApi.visitor (2340 documents)
2026-01-31T20:36:41.547+0000	writing CampApiDB.mySessions to archive '/data/db/full-backup.archive'
2026-01-31T20:36:41.751+0000	done dumping CampApiDB.bookings (9 documents)
2026-01-31T20:36:41.753+0000	writing MenuApi.login to archive '/data/db/full-backup.archive'
2026-01-31T20:36:41.856+0000	done dumping CampApiDB.mySessions (0 documents)
2026-01-31T20:36:41.858+0000	writing CampApiDB.Sessions to archive '/data/db/full-backup.archive'
2026-01-31T20:36:41.947+0000	done dumping MenuApi.login (0 documents)
2026-01-31T20:36:41.949+0000	writing config.tenantMigrationDonors to archive '/data/db/full-backup.archive'
2026-01-31T20:36:42.149+0000	done dumping campdb.Enquirys (5 documents)
2026-01-31T20:36:42.154+0000	writing config.external_validation_keys to archive '/data/db/full-backup.archive'
2026-01-31T20:36:42.357+0000	done dumping config.external_validation_keys (0 documents)
2026-01-31T20:36:42.449+0000	writing config.tenantMigrationRecipients to archive '/data/db/full-backup.archive'
2026-01-31T20:36:42.752+0000	done dumping MenuApi.user (3 documents)
2026-01-31T20:36:42.850+0000	done dumping CampApiDB.Sessions (0 documents)
2026-01-31T20:36:42.852+0000	done dumping config.tenantMigrationDonors (0 documents)
2026-01-31T20:36:42.953+0000	done dumping config.tenantMigrationRecipients (0 documents)

```

```
kubectl exec mongo-0 -c mongo -- ls -lh /data/db/full-backup.archive
kubectl cp mongo-0:/data/db/full-backup.archive /Users/coderprabhu/git/coderprabhu-k8s/full-backup.archive -c mongo
```


Item	Status
Backup file	full-backup.archive
Size	94 KB (compressed)
Location	/Users/coderprabhu/git/coderprabhu-k8s/full-backup.archive
Documents	4,448 total


```
mongorestore \
  --uri="mongodb+srv://UNAME:PW@cluster0.cd1r6ev.mongodb.net/" \
  --archive=/Users/coderprabhu/git/coderprabhu-k8s/full-backup.archive \
  --gzip

```