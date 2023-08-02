#!/usr/bin/env bash

cd REAL/json_lemmy/
for line in *; do echo -n "$line "; date -d@${line:: -8} +"%Y-%m-%d %R"; done


