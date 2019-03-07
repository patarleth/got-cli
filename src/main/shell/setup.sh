#!/usr/bin/env bash

SETUP_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR=$(realpath "$SETUP_SCRIPT_DIR/../../..")
DB_DIR="$PROJECT_DIR/gotdb"
DATA_DIR="$PROJECT_DIR/data"

echo "$PROJECT_DIR"

ldb_init() {
    if command -v ldb > /dev/null; then
        echo ldb installed
    else
        echo ldb not installed
        brew install jq snappy cmake
    fi
}

ldb_create() {
    if [ -e "$DB_DIR" ]; then
        echo $(basename "$DB_DIR") db exists
    else
        echo ldb "$DB_DIR" --create
    fi
}

ldb_curl_data() {
    if [ ! -e "$DATA_DIR" ]; then
        mkdir -p "$DATA_DIR"
    fi
    
    if [ -f "$DATA_DIR/houses.json" ]; then
        echo houses.json exists
    else
        echo downloading houses data
        curl -s 'https://raw.githubusercontent.com/joakimskoog/AnApiOfIceAndFire/master/data/houses.json' | jq . > "$DATA_DIR/houses.json"
    fi
    
    if [ -f "$DATA_DIR/characters.json" ]; then
        echo characters.json exists
    else
        echo downloading character data
        curl -s 'https://raw.githubusercontent.com/joakimskoog/AnApiOfIceAndFire/master/data/characters.json' | jq . > "$DATA_DIR/characters.json"
    fi
    
    if [ -f "$DATA_DIR/books.json" ]; then
        echo books.json exists
    else
        echo downloading book data
        curl -s 'https://raw.githubusercontent.com/joakimskoog/AnApiOfIceAndFire/master/data/books.json' | jq . > "$DATA_DIR/books.json"
    fi

}

ldb_add_houses() {
    echo adding house data
    local B_IFS="$IFS"
    IFS=$'\n'
    local all=($(jq -c '.[]' "$DATA_DIR/houses.json"))
    echo "house sample - ${all[0]}"
    echo number of houses ${#all[@]}
    IFS="$B_IFS"

    for house in "${all[@]}"; do
        local id="house-$(jq -c '.Id' <<<"$house")"
        # echo "house Id $id"
        err="$(ldb "$DB_DIR" get "$id" 2>&1 > /dev/null)"
        if [ "$err" != "" ]; then
            ldb "$DB_DIR" put "$id" "$house"
        fi
    done
}

ldb_add_characters() {
    echo adding character data
    local B_IFS="$IFS"
    IFS=$'\n'
    local all=($(jq -c '.[]' "$DATA_DIR/characters.json"))
    echo "character sample ${all[0]}"
    echo number of characters ${#all[@]}
    IFS="$B_IFS"

    for character in "${all[@]}"; do
        local id="character-$(jq -c '.Id' <<<"$character")"
        # echo "character Id $id"
        err="$(ldb "$DB_DIR" get "$id" 2>&1 > /dev/null)"
        if [ "$err" != "" ]; then
            ldb "$DB_DIR" put "$id" "$character"
        fi
    done
}

ldb_add_books() {
    echo adding book data
    local B_IFS="$IFS"
    IFS=$'\n'
    local all=($(jq -c '.[]' "$DATA_DIR/books.json"))
    echo "book sample ${all[0]}"
    echo number of books ${#all[@]}
    IFS="$B_IFS"

    for book in "${all[@]}"; do
        local id="book-$(jq -c '.Id' <<<"$book")"
        # echo "book Id $id" 
        err="$(ldb "$DB_DIR" get "$id" 2>&1 > /dev/null)"
        if [ "$err" != "" ]; then
            ldb "$DB_DIR" put "$id" "$book"
        fi
    done
}

ldb_init
ldb_create
ldb_curl_data
ldb_add_houses
ldb_add_characters
ldb_add_books
