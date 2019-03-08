#!/usr/bin/env bash

SETUP_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR=$(realpath "$SETUP_SCRIPT_DIR/../../..")
DB_DIR="$PROJECT_DIR/gotdb"
DATA_DIR="$PROJECT_DIR/data"
BLACKLIST=(a the and of)

echo "$PROJECT_DIR"

ldb_next_letter () {
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
        ldb "$DB_DIR" --create --size
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

ldb_escape_ticks() {
    echo "${1//\'/\'\\\'\'}"
}

ldb_put() {
    local key="$1"
    local val="$(ldb_escape_ticks "$2")"

    local msg="ldb $DB_DIR put "
    msg+="'${key}' "
    msg+="'${val}'"
    msg+="; echo ${key}"
        
    echo "$msg" >> "$DATA_DIR/puts.sh"
}

ldb_contains_element () {
  local e match="$1"
  shift
  for e; do
      if [[ "$e" == "$match" ]]; then
          echo "true"
        return 0
      fi
  done

  echo "false"  
  return 1
}

ldb_add_index() {
    local table="$1"
    local id="$2"
    local fieldName="$3"
    local json="$4"
    local prefix="${table}_${fieldName,,}_"
    
    local jqCmd='.'
    jqCmd+="$fieldName"

    local rawValue="$(jq -c "$jqCmd" <<<"$json")"
    rawValue="${rawValue,,}"
    # echo "rawValue ${rawValue} jqCmd ${jqCmd}" json ${json}"

    local parts=("$rawValue")

    # local B_IFS="$IFS"
    # IFS=' '
    # parts+=($rawValue)
    # IFS="$B_IFS"

    for part in "${parts[@]}"; do
        part=${part//[^ a-zA-Z0-9]/}
        local contains="$(ldb_contains_element "$part" "${BLACKLIST[@]}")"
        if [ ! "${contains}" == "true" ] ; then
            local fieldValueToIndex="${prefix}${part}"
            if [ ! "$fieldValueToIndex" == "${prefix}" ]; then
                echo adding secondary index to "$table" - "$id" - "$fieldName" - "${prefix}" - "$fieldValueToIndex"
                echo "$fieldValueToIndex __ $id" >> "$DATA_DIR/index.txt"
            fi
        fi
    done
}

ldb_query_index() {
    local table="$1"
    local index="$2"
    local start="$3"

    local msgKey="${table}_${index}_${start}"
    local msg="in ${msgKey}"
    local resultStr="$(echo "$msg" | ldb "$DB_DIR" 2> /dev/null | egrep "$msgKey")"
    
    local B_IFS="$IFS"
    IFS=$'\n'
    local all=($resultStr)
    IFS="$B_IFS"

    # echo "$resultStr"
    # echo "${#all[@]}"
    local resultJson='[]'
    for bookKey in "${all[@]}"; do
        bookKey="$(sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" <<< ${bookKey} | tr -d '[:cntrl:]')"
        # echo "- ${bookKey} -"

        local nextKeyArray="$(ldb "$DB_DIR" get "$bookKey")"
        # echo "$nextKeyArray"

        local jqCmd='. += '
        jqCmd+="${nextKeyArray}"
                    
        resultJson="$(echo "${resultJson}" | jq -c "${jqCmd}")"
    done

    echo "$resultJson"
}

ldb_values_json_array() {
    local jsonIdArray="$(echo "$1" | jq -r .[])"
    # echo "jsonIdArray ${jsonIdArray}"
    local B_IFS="$IFS"
    IFS=$'\n'
    local ids=($jsonIdArray)
    IFS="$B_IFS"
    
    local resultJson='[]'
    for id in "${ids[@]}"; do
        # echo "$id"
        local jsonVal="$(ldb "$DB_DIR" get "$id")"
        # echo ${jsonVal}
        local jqCmd='. += '
        jqCmd+="[ ${jsonVal} ]"

        resultJson="$(echo "${resultJson}" | jq -c "${jqCmd}")"
    done
    echo "$resultJson"
}

ldb_book_name_contains_word() {
    local word="$1"
    local query='.*'
    query+="$word"
    
    ldb_values_json_array "$(ldb_query_index book name "${query}")"
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
            ldb_put "$id" "$house"
        fi
    done
}

ldb_add_house_secondary() {
    echo adding house secondary index
    local B_IFS="$IFS"
    IFS=$'\n'
    local all=($(jq -c '.[]' "$DATA_DIR/houses.json"))
    echo "house sample - ${all[0]}"
    echo number of houses ${#all[@]}
    IFS="$B_IFS"

    for house in "${all[@]}"; do
        local id="house_$(jq -c '.Id' <<<"$house")"
        ldb_add_index "house" "$id" "Name" "$house"
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
            echo adding "$id"
            ldb_put "$id" "$character"
        fi
    done
}

ldb_add_character_secondary() {
    echo adding character secondary index
    local B_IFS="$IFS"
    IFS=$'\n'
    local all=($(jq -c '.[]' "$DATA_DIR/characters.json"))
    echo "character sample - ${all[0]}"
    echo number of characters ${#all[@]}
    IFS="$B_IFS"

    for character in "${all[@]}"; do
        local id="character_$(jq -c '.Id' <<<"$character")"
        ldb_add_index "character" "$id" "Name" "$character"
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
            ldb_put "$id" "$book"
        fi
    done
}

ldb_add_book_secondary() {
    echo adding book secondary index
    local B_IFS="$IFS"
    IFS=$'\n'
    local all=($(jq -c '.[]' "$DATA_DIR/books.json"))
    echo "book sample - ${all[0]}"
    echo number of books ${#all[@]}
    IFS="$B_IFS"

    for book in "${all[@]}"; do
        local id="book_$(jq -c '.Id' <<<"$book")"
        ldb_add_index "book" "$id" "Name" "$book"
    done
}

ldb_build_index_puts() {
    local B_IFS="$IFS"
    IFS=$'\n'
    local indexParts=($(cat "$DATA_DIR/index.sorted.txt"))
    local lastArray='[]'
    local lastKey=
    IFS="$B_IFS"

    local regex='(.*) __ (.*)'
    for next in "${indexParts[@]}"; do
        if [[ "$next" =~ $regex ]]; then
            local key="${BASH_REMATCH[1]}"
            local pk="${BASH_REMATCH[2]}"

            local jqCmd='. += [ "'
            jqCmd+="$pk"
            jqCmd+='" ]'
            
            if [ "$lastKey" == "" ] || [ "$key" == "$lastKey" ]; then
                local before="$lastArray"
                lastArray="$(echo "$lastArray" | jq -c "$jqCmd")"
                local after="$lastArray"
                # echo "before $before after $after jqCmd $jqCmd"
            else
                ldb_put "${key}" "${lastArray}"
                lastArray="$(echo '[]' | jq -c "$jqCmd")"
            fi

            lastKey="$key"
        fi
    done
}

ldb_add_data() {
    ldb_curl_data
    rm -rf "$DATA_DIR/puts.sh"
    touch "$DATA_DIR/puts.sh"
    chmod 777 "$DATA_DIR/puts.sh"

    ldb_add_books
    ldb_add_houses
    ldb_add_characters

    rm -rf "$DATA_DIR/index.txt"
    touch "$DATA_DIR/index.txt"

    ldb_add_book_secondary
    ldb_add_house_secondary
    # ldb_add_character_secondary
    sort "$DATA_DIR/index.txt" > "$DATA_DIR/index.sorted.txt"

    ldb_build_index_puts
    
    "$DATA_DIR/puts.sh"
}

# ldb_init && ldb_create


