#!/bin/bash

./shell.sh test --eval 'db.test.insert({"name":"rob"})'
./shell.sh test --eval 'db.test.find()'
