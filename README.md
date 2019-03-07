# got-cli

first things first - install leveldb cli

https://github.com/heapwolf/ldb

```
$ brew install jq snappy cmake
$ git clone https://github.com/heapwolf/ldb.git
$ make install -C ldb
```

next create the db

```
$ ldb ./gotdb --create
```

time to load the data from AnApiOfIceAndFire

```
https://raw.githubusercontent.com/joakimskoog/AnApiOfIceAndFire/master/data/houses.json
```
