#!/usr/bin/env bash

SETUP_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR=$(realpath "$SETUP_SCRIPT_DIR/../../..")
DB_DIR="$PROJECT_DIR/gotdb"
DATA_DIR="$PROJECT_DIR/data"

echo "$PROJECT_DIR"

function ldb_next_letter () {
    local Rest Letters=abcdefghijklmnopqrstuvwxyz
    Rest=${Letters#*$1}
    echo ${Rest:0:1}
}

ldb_append_id_to_array() {
    local id="$1"
    local json="$2";

    if [ "$json" == "" ]; then
        json='[]'
    fi

    local jqCmd='. += [ "'
    jqCmd+="$id"
    jqCmd+='" ]'
    jq -c "$jqCmd" <<< "$json"
}

ldb_array_index() {
    local id="$1"
    local json="$2"

    local jqCmd='. | index ("'
    jqCmd+="$id"
    jqCmd+='" )'
    
    local index="$(jq -r "$jqCmd" <<<"$json")"
    if [ ! "$index" == "null" ]; then
        echo "$index"
    fi
}

ldb_create() {
    if [ -d "$DB_DIR" ]; then
        echo "$(basename "$DB_DIR") db exists"
    else
        echo creating db "$DB_DIR"
        ldb "$DB_DIR" --create
    fi
}

ldb_init() {
    if command -v ldb > /dev/null; then
        echo ldb installed
    else
        echo ldb not installed
        brew install jq snappy cmake
    fi

    ldb_create
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

ldb_add_index() {
    local table="$1"
    local id="$2"
    local fieldName="$3"
    local json="$4"
    local prefix="$table_${fieldName,,}_"
    
    local jqCmd='.'
    jqCmd+="$fieldName"

    local rawValue="$(jq -c "$jqCmd" <<<"$json")"
    rawValue="${rawValue,,}"
    # echo "rawValue ${rawValue} jqCmd ${jqCmd}" json ${json}"
    
    local fieldValueToIndex="${prefix}${rawValue}"
    if [ ! "$fieldValueToIndex" == "${prefix}" ]; then
        echo adding secondary index to "$table" - "$id" "$fieldName" "$fieldValueToIndex"
        # bout std out
        # berr std err
        . <({ berr=$({ bout=$(ldb "$DB_DIR" get "$fieldValueToIndex"); } 2>&1; declare -p bout >&2); declare -p berr; } 2>&1)
        
        if [ "$(ldb_array_index "$id" "$bout")" == "" ]; then
            ldb "$DB_DIR" put "$fieldValueToIndex" "$(ldb_append_id_to_array "$id", "$bout")"
        fi
    fi
}

ldb_query_index() {
    local table="$1"
    local start="$2"
    local firstLetter="${start:0:1}"
    local nextLetter="$(ldb_next_letter $firstLetter)"

    ldb
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
        local id="house_$(jq -c '.Id' <<<"$house")"
        # echo "house Id $id"
        err="$(ldb "$DB_DIR" get "$id" 2>&1 > /dev/null)"
        if [ ! "$err" == "" ]; then
            echo adding "$id"
            ldb "$DB_DIR" put "$id" "$house"
            ldb_add_index "house" "$id" "Name" "$house"
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
        local id="character_$(jq -c '.Id' <<<"$character")"
        # echo "character Id $id"
        err="$(ldb "$DB_DIR" get "$id" 2>&1 > /dev/null)"
        if [ ! "$err" == "" ]; then
            ldb "$DB_DIR" put "$id" "$character"
            ldb_add_index "character" "$id" "Name" "$character"
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
        local id="book_$(jq -c '.Id' <<<"$book")"
        # echo "book Id $id" 
        err="$(ldb "$DB_DIR" get "$id" 2>&1 > /dev/null)"
        if [ ! "$err" == "" ]; then
            ldb "$DB_DIR" put "$id" "$book"
            ldb_add_index "book" "$id" "Name" "$book"
        fi
    done
}

lbd_add_data() {
    ldb_curl_data
    ldb_add_books
    ldb_add_houses
    ldb_add_characters
}

# ldb_init && ldb_create


