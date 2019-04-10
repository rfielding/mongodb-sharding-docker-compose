# mongodb-sharding-docker-compose

:whale: docker-compose stack that allows you to turn on a full MongoDB sharded cluster with the following components :

 * configserver replicaset: 3x mongod with configsrv enabled 
 * first replicaset shard: 3x mongod 
 * second replicaset shard: 3x mongod
 * third replicaset shard: 3x mongod
 * fourth replicaset shard: 3x mongod
 * mongo query router: 1x mongos
 * authentication enabled + global auth key certificate between nodes

> This means a replication factor of 3, with data sharded into 4.  This means that we can store 4x what any single server can store, and store everything redundantly 3 times.  2 of the 3 of every replica set must survive in order to never lose data.

# To get started

```bash
 git clone git@github.com:rfielding/mongodb-sharding-docker-compose.git
 cd mongodb-sharding-docker-compose
 ./down.sh && rm -rf data && ./up.sh 
```

To re-run clean (deleted data)

```bash
 ./down.sh && rm -rf data && ./up.sh 
```

# How It Works

## Config Server

This is much like a Zookeeper or Consul cluster.  A majority of these nodes must always be up to serve config.

```javascript
rs.initiate(
   {
      _id: "mongo-configserver",
      configsvr: true,
      version: 1,
      members: [
         { _id: 0, host : "mongo-configserver-01:27017" },
         { _id: 1, host : "mongo-configserver-02:27017" },
         { _id: 2, host : "mongo-configserver-03:27017" }
      ]
   }
)
```


Then per-shard initiation begins.  When we go to initiate each primary for a shard, we pipe a script into that primary (`a`) like this:

```javascript
rs.initiate(
   {
      _id: "mongo-shard-01",
      version: 1,
      members: [
         { _id: 0, host : "mongo-shard-01a:27018" },
         { _id: 1, host : "mongo-shard-01b:27018" },
         { _id: 2, host : "mongo-shard-01c:27018" }
      ]
   }
)
```

This config is sent to the primary (`a`) representing each shard.

```bash
docker exec -it mongodbdocker_mongo-shard-03a_1 sh -c "mongo --port 27020 < /mongo-shard-03.init.js"
```

This associates the shard with the machines

```bash
// mongo-shard-03
sh.addShard( "mongo-shard-03/mongo-shard-03a:27020")
sh.addShard( "mongo-shard-03/mongo-shard-03b:27020")
sh.addShard( "mongo-shard-03/mongo-shard-03c:27020")
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

To see what is going on here, look at the processes that are running.

```
docker-compose ps
```

Notice that the shards are from `01` to `04` and `a` to `c`.  The idea is that each machine
can hold about 1/4 of the data.  The shard is replicated to 3 machines (replication factor).

```
                Name                               Command               State     Ports  
------------------------------------------------------------------------------------------
mongodbdocker_mongo-configserver-01_1   docker-entrypoint.sh mongo ...   Up      27017/tcp
mongodbdocker_mongo-configserver-02_1   docker-entrypoint.sh mongo ...   Up      27017/tcp
mongodbdocker_mongo-configserver-03_1   docker-entrypoint.sh mongo ...   Up      27017/tcp
mongodbdocker_mongo-router-01_1         docker-entrypoint.sh mongo ...   Up      27017/tcp
mongodbdocker_mongo-shard-01a_1         docker-entrypoint.sh mongo ...   Up      27017/tcp
mongodbdocker_mongo-shard-01b_1         docker-entrypoint.sh mongo ...   Up      27017/tcp
mongodbdocker_mongo-shard-01c_1         docker-entrypoint.sh mongo ...   Up      27017/tcp
mongodbdocker_mongo-shard-02a_1         docker-entrypoint.sh mongo ...   Up      27017/tcp
mongodbdocker_mongo-shard-02b_1         docker-entrypoint.sh mongo ...   Up      27017/tcp
mongodbdocker_mongo-shard-02c_1         docker-entrypoint.sh mongo ...   Up      27017/tcp
mongodbdocker_mongo-shard-03a_1         docker-entrypoint.sh mongo ...   Up      27017/tcp
mongodbdocker_mongo-shard-03b_1         docker-entrypoint.sh mongo ...   Up      27017/tcp
mongodbdocker_mongo-shard-03c_1         docker-entrypoint.sh mongo ...   Up      27017/tcp
mongodbdocker_mongo-shard-04a_1         docker-entrypoint.sh mongo ...   Up      27017/tcp
mongodbdocker_mongo-shard-04b_1         docker-entrypoint.sh mongo ...   Up      27017/tcp
mongodbdocker_mongo-shard-04c_1         docker-entrypoint.sh mongo ...   Up      27017/tcp
```

If we wanted to have 10 shards with a replication factor of 3, then we would have shards up to `10`.

```
// mongo-shard-01
sh.addShard( "mongo-shard-01/mongo-shard-01a:27018")
sh.addShard( "mongo-shard-01/mongo-shard-01b:27018")
sh.addShard( "mongo-shard-01/mongo-shard-01c:27018")

// mongo-shard-02
sh.addShard( "mongo-shard-02/mongo-shard-02a:27019")
sh.addShard( "mongo-shard-02/mongo-shard-02b:27019")
sh.addShard( "mongo-shard-02/mongo-shard-02c:27019")

// mongo-shard-03
sh.addShard( "mongo-shard-03/mongo-shard-03a:27020")
sh.addShard( "mongo-shard-03/mongo-shard-03b:27020")
sh.addShard( "mongo-shard-03/mongo-shard-03c:27020")

// mongo-shard-04
sh.addShard( "mongo-shard-04/mongo-shard-04a:27020")
sh.addShard( "mongo-shard-04/mongo-shard-04b:27020")
sh.addShard( "mongo-shard-04/mongo-shard-04c:27020")

...
```
