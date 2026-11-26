# Databases

Databases: `CoderPraBhuApi`, `CampApiDB`, `MenuApi`, `campdb`.

- **`allprojects-v2`** (current): no in-cluster MongoDB. Apps use MongoDB Atlas via the
  `mongodb-atlas-config` ConfigMap and `mongodb-atlas-secret` Secret.
- **`coderprabhu-cluster`** (legacy): in-cluster MongoDB StatefulSet (`mongo-0`, see
  `legacy/old-clusters/coderprabhu-mongo-*.yaml`; the cluster is deleted).

Never commit credentials, Atlas hostnames, visitor data (e.g. IP addresses) or backup archives.

## Local development

Apps default to `mongodb://localhost:27017/<DbName>`, so any local MongoDB works. Use `mongosh`
to inspect data. Prefer checking app data through the app's API (e.g. coderprabhu-api `/count`).

## Legacy: in-cluster MongoDB (`coderprabhu-cluster` only)

The pod runs MongoDB 4.4, so the shell inside it is the legacy `mongo` shell.

Shell into the pod:
```
kubectl exec -it mongo-0 -c mongo -- bash
mongo
show databases
use CoderPraBhuApi
show collections
db.visitor.find()
db.visitor.aggregate([ { $sortByCount: "$ip" } ]);
db.visitor.remove({ip: "<ip-address>"})
```

List databases and collection sizes:
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
```

## Backup and restore to Atlas

Full backup from the pod, copy it out, restore into Atlas:
```
kubectl exec mongo-0 -c mongo -- mongodump --archive=/data/db/full-backup.archive --gzip
kubectl exec mongo-0 -c mongo -- ls -lh /data/db/full-backup.archive
kubectl cp mongo-0:/data/db/full-backup.archive ./full-backup.archive -c mongo

mongorestore \
  --uri="mongodb+srv://<user>:<password>@<atlas-cluster-host>/" \
  --archive=./full-backup.archive \
  --gzip
```

The Jan 2026 backup (about 4.4k documents, 94 KB compressed) covered all four databases; the bulk was
`CoderPraBhuApi.visitor` and `MenuApi.visitor`.
