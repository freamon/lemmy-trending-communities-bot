#!/usr/bin/env bash

set +H

MODE=${1}

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
if [ ! -d ${SCRIPT_DIR}/${MODE} ]
then
    echo "Error: ${SCRIPT_DIR}/${MODE} doesn't exist"
    exit
else
    cd ${SCRIPT_DIR}
fi

sleep_period=61m

while true
do
    sleep $sleep_period
    rm -f /tmp/lv_meta.json
    curl -L -o /tmp/lv_meta.json https://data.lemmyverse.net/data/meta.json
    latest=$(jq .time /tmp/lv_meta.json)

    if [[ $? -eq 0 && "${latest}" != "null" ]]
    then
        if [ ! -f REAL/jsons/${latest}.json ]
        then
            curl -L -o REAL/jsons/${latest}.json https://data.lemmyverse.net/data/community.full.json
            ${SCRIPT_DIR}/tcbot.sh ${MODE} ${latest} 0 LOOP
            sleep_period=6h
        else
            sleep_period=61m
        fi
    fi
done

