# lemmy-trending-communities-bot
BASH scripts for posting trending Communities on Lemmy

Results are posted at    
https://feddit.nl/c/trendingcommunities   
https://lemmynsfw.com/c/trendingcommunities (log in with an account that shows NSFW posts to view)

## usage
`./get_latest_jsons.sh`
will get new JSON files for Lemmy if they're available

`./tcbot TEST (JSON-TIMESTAMP) 0` 

## Examples

TEST/ contains 1690956302001.txt		(a file from 2023-08-02 06:05)

`./tcbot TEST 1690977937996 0`        (from 2023-08-02 12:05, so would add its data to 1690956302001.txt)    
`./tcbot TEST 1690999474501 0`        (from 2023-08-02 18:04, so would add its data to 1690956302001.txt)    
`./tcbot TEST 1691021655097 0`        (from 2023-08-03 00:14, so would add its data to 1690956302001.txt)   
`./tcbot TEST 1691042690884 0`        (from 2023-08-03 06:04, 24 hours later than 1690956302001, so would calculate growth)   

#### If you wanted to start from scratch

(assuming you've just download 1691042690884.json)   
`rm TEST/*`   
`./tcbot TEST 1691042690884 0`

## Note

REAL mode is for uploading growth stats to a Lemmy Community, so requires files in REAL/community and REAL/logins 
to be populated
