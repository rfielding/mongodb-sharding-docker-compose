# mongodb-sharding-docker-compose

:whale: docker-compose stack that allows you to turn on a full MongoDB sharded cluster with the following components :

 * configserver replicaset: 3x mongod with configsrv enabled 
 * first replicaset shard: 3x mongod 
 * second replicaset shard: 3x mongod
 * third replicaset shard: 3x mongod
 * mongo query router: 1x mongos
 * authentication enabled + global auth key certificate between nodes

To get started

```bash
 git clone git@github.com:rfielding/mongodb-sharding-docker-compose.git
 cd mongodb-sharding-docker-compose
 ./down.sh && rm -rf data && ./up.sh 
```

To re-run clean (deleted data)

```bash
 ./down.sh && rm -rf data && ./up.sh 
```

You can also edit mongo-auth.init.js to change admin credentials before turning up the cluster

```javascript
    admin = db.getSiblingDB("admin")
    admin.createUser(
      {
         user: "admin",
         pwd: "admin",
         roles: [ { role: "root", db: "admin" } ] 
      }
    )
```

Peek around inside

```bash
./shell.sh admin
```

Smoke test it

```bash
./test0.sh
```  

