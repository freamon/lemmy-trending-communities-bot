#!/usr/bin/env bash

rm -f /tmp/lv_meta.json
curl -L -o /tmp/lv_meta.json https://data.lemmyverse.net/data/meta.json
latest=$(jq .time /tmp/lv_meta.json)

if [[ $? -eq 0 && "${latest}" != "null" ]]
then
    if [ ! -f REAL/json_lemmy/${latest}.json ]
    then
        curl -L -o REAL/json_lemmy/${latest}.json https://data.lemmyverse.net/data/community.full.json
    else
        echo "Already have latest JSON for Lemmy Communities"
    fi

    if [ ! -f REAL/json_kbin/${latest}.json ]
    then
        curl -L -o REAL/json_kbin/${latest}.json https://data.lemmyverse.net/data/magazines.full.json
    else
        echo "Already have latest JSON for KBIN Magazines"
    fi
else
	echo "Error downloading from lemmyverse.net"
fi
