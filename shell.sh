#!/bin/bash

docker exec -it mongodbdocker_mongo-router-01_1 mongo -u'admin' -p'admin' --authenticationDatabase=admin localhost:27017/$1 $2 $3
