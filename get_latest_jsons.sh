#!/usr/bin/env bash

for m in {"curl","jq"}
do 
    command -v ${m} &> /dev/null
    if [ $? -ne 0 ]
    then 
        echo "Error: Missing '${m}'. Install it from your distro's repo"
        exit
    fi
done

rm -f /tmp/lv_meta.json
curl -L -o /tmp/lv_meta.json https://data.lemmyverse.net/data/meta.json
latest=$(jq .time /tmp/lv_meta.json)

if [[ $? -eq 0 && "${latest}" != "null" ]]
then
    if [ ! -f REAL/jsons/${latest}.json ]
    then
        curl -L -o REAL/jsons/${latest}.json https://data.lemmyverse.net/data/community.full.json
    else
        echo "Already have latest JSON for Lemmy Communities"
    fi
else
	echo "Error downloading from lemmyverse.net"
fi
