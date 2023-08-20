# lemmy-trending-communities-bot
BASH scripts for posting trending Communities on Lemmy

Results are posted at  
https://feddit.nl/c/trendingcommunities  
https://lemmynsfw.com/c/trendingcommunities (log in with an account that shows NSFW posts to view)  

## Usage  
Relevant files:  
REAL/jsons/1692511506610.json, provided by [LemmyVerse](lemmyverse.net) on 2023-08-20 06:05  
TEST/1692425096956.txt, derived from data provided the day before, on 2023-08-19 06:04  
TEST/lastrun.txt, with a single line, for yesterday's timestamp of 1692425096956  

Run  
`./tcbot.sh TEST 1692511506610`  
to show subscriber growth from 2023-08-19 06:04 to 2023-08-20 06:05  

The above command will also update the files in TEST, so 1692511506610 becomes the new starting point.  
New data can be retrieved by running `get_latest_jsons.sh`  
When used as a argument to the script, growth will be shown if there's a 24 hour gap between the json and last_run_timestamp.txt  

Everything in TEST can safely be deleted if you want to start from scratch  

## Note

REAL mode is for uploading growth stats to a Lemmy Community, so requires files in REAL/community and REAL/logins
to be populated
