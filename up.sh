#!/bin/bash

## Composer project name instead of git main folder name
export COMPOSE_PROJECT_NAME=mongodbdocker

## Generate global auth key between cluster nodes
openssl rand -base64 756 > mongodb.key
chmod 600 mongodb.key

mkdir data > /dev/null 2>&1

declare -a copies=(a b c)
declare -a shards=(01 02 03 04)

##
## Generate the docker-compose file, and init scripts, so we can vary shard count
##
echo "version: '2'" > docker-compose.yml
echo "services:" >> docker-compose.yml
cfgurl=
echo "rs.initiate({_id:'mongo-configserver',configsvr:true,version:1,members:[" > mongo-configserver.init.js
n=0
for copy in ${copies[@]}
do
  echo "  mongo-configserver-${copy}:" >> docker-compose.yml
  echo "    image: mongo" >> docker-compose.yml
  echo "    command: mongod --auth --port 27017 --configsvr --replSet mongo-configserver --dbpath /data/db --keyFile /mongodb.key" >> docker-compose.yml
  echo "    volumes:" >> docker-compose.yml
  echo "        - ./mongodb.key:/mongodb.key" >> docker-compose.yml
  echo "        - ./mongo-configserver.init.js:/mongo-configserver.init.js" >> docker-compose.yml
  echo "        - ./data/mongo-configserver-${copy}:/data/db" >> docker-compose.yml
  if [ "x$cfgurl" == "x" ]
  then
    true
  else
    echo "," >> mongo-configserver.init.js
  fi
  echo -n "{_id:${n},host:'mongo-configserver-${copy}:27017'}" >> mongo-configserver.init.js
  cfgurl="$cfgurl,mongo-configserver-${copy}:27017"
  n=$((n+1))
done
echo "]})" >> mongo-configserver.init.js
cfgurl="${cfgurl:1}"
shardn=27017
for shard in ${shards[@]}
do
  shardn=$((shardn+1))
  for copy in ${copies[@]}
  do
    echo "  mongo-shard-${shard}${copy}:" >> docker-compose.yml
    echo "    image: mongo" >> docker-compose.yml
    echo "    command: mongod --auth --port ${shardn} --shardsvr --replSet mongo-shard-${shard} --dbpath /data/db  --keyFile /mongodb.key" >> docker-compose.yml
    echo "    volumes:" >> docker-compose.yml
    echo "        - ./mongodb.key:/mongodb.key" >> docker-compose.yml
    echo "        - ./mongo-shard-${shard}.init.js:/mongo-shard-${shard}.init.js" >> docker-compose.yml
    echo "        - ./data/mongo-shard-${shard}${copy}:/data/db" >> docker-compose.yml
  done
done
echo "  mongo-router-01:" >> docker-compose.yml
echo "    image: mongo" >> docker-compose.yml
echo "    command: mongos --port 27017 --configdb mongo-configserver/${cfgurl} --keyFile /mongodb.key" >> docker-compose.yml
echo "    volumes:" >> docker-compose.yml
echo "        - ./mongodb.key:/mongodb.key" >> docker-compose.yml
echo "        - ./mongo-sharding.init.js:/mongo-sharding.init.js" >> docker-compose.yml
echo "        - ./mongo-auth.init.js:/mongo-auth.init.js" >> docker-compose.yml
echo "        - ./data/mongo-router-01:/data/db" >> docker-compose.yml
echo "    depends_on:" >> docker-compose.yml
for copy in ${copies[@]}
do
  echo "      - mongo-configserver-${copy}" >> docker-compose.yml
done
for shard in ${shards[@]}
do
  for copy in ${copies[@]}
  do
    echo "      - mongo-shard-${shard}${copy}" >> docker-compose.yml
  done
done
echo "" > mongo-sharding.init.js
shardn=27017
for shard in ${shards[@]}
do
  shardn=$((shardn+1))
  echo "rs.initiate({_id:'mongo-shard-${shard}',version:1,members:[" > mongo-shard-${shard}.init.js
  members=
  n=0
  for copy in ${copies[@]}
  do
    if [ "x$members" == "x" ]
    then
      true
    else
      echo "," >> mongo-shard-${shard}.init.js
    fi
    echo -n "{_id:${n},host:'mongo-shard-${shard}${copy}:${shardn}'}" >> mongo-shard-${shard}.init.js
    members=${copy}
    echo "sh.addShard('mongo-shard-${shard}/mongo-shard-${shard}${copy}:${shardn}')" >> mongo-sharding.init.js
    n=$((n+1))
  done
  echo "]})" >> mongo-shard-${shard}.init.js
done

#
# All files are now created.  Do the setup.
# 
docker-compose up -d 
sleep 60
echo seed the config server
docker exec -it mongodbdocker_mongo-configserver-a_1 sh -c "/usr/bin/mongo --port 27017 < /mongo-configserver.init.js"
shardn=27017
for shard in ${shards[@]}
do
  shardn=$((shardn+1))
  echo seed shard ${shard}
  docker exec -it mongodbdocker_mongo-shard-${shard}a_1 sh -c "/usr/bin/mongo --port ${shardn} < /mongo-shard-${shard}.init.js" 
done
sleep 15
echo configure router sharding
docker exec -it mongodbdocker_mongo-router-01_1 sh -c "/usr/bin/mongo --port 27017 < /mongo-sharding.init.js"
echo auth init
docker exec -it mongodbdocker_mongo-router-01_1 sh -c "/usr/bin/mongo --port 27017 < /mongo-auth.init.js"
