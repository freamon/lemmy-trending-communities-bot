#!/usr/bin/env bash

cd REAL/jsons/
for line in *; do echo -n "$line "; date -d@${line:: -8} +"%Y-%m-%d %R"; done


