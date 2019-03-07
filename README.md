# got-cli

first things first - install leveldb cli

https://github.com/heapwolf/ldb

### tldr; - run this

```
$ src/main/shell/setup.sh
$ ldb_init
$ ldb_create
$ lbd_add_data
```

get a cup of coffee, this takes a while ;)


### what that did - 

#### installs this

```
$ brew install jq snappy cmake
$ git clone https://github.com/heapwolf/ldb.git
$ make install -C ldb
```

#### create a db

```
$ ldb ./gotdb --create
```

#### loads the data from AnApiOfIceAndFire

```
https://raw.githubusercontent.com/joakimskoog/AnApiOfIceAndFire/master/data/houses.json
https://raw.githubusercontent.com/joakimskoog/AnApiOfIceAndFire/master/data/characters.json
https://raw.githubusercontent.com/joakimskoog/AnApiOfIceAndFire/master/data/books.json
```

#### into pk index per table like so

```
book_1 -> {...book json...}
character_1 -> {...character json...}
house_1 -> {...family house json...}
```

#### secondary indexes created on Name look like 

```
book_name_arleth -> ["book_20"]
```

key is table_field_&lt;indexed value&gt; -> arrays of ids
