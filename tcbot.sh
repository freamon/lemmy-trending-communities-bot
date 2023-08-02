#!/usr/bin/env bash

set +H

# tcbot.sh
# called with tcbot.sh MODE JSON DAYS [LOOP]
# MODE = TEST or REAL, to just view results or to upload to Lemmy
# JSON = json file downloaded from data.lemmyverse.net
# DAYS = time period, (e.g. 0=today, 5=5 days ago, -1=tomorrow)
# LOOP = Optional, to indicate this script was called from fetch_jsons.sh script

# Both TEST and REAL use data from the REAL directory
# But if you want to use REAL to upload to Lemmy, you'll need to update the files in
# REAL/community/ and REAL/logins/

if [ $# -lt 3 ]
then
    echo "Usage: tcbot.sh MODE JSON DAYS [LOOP]"
    exit
fi

MODE=${1}
JSON=${2}
DAYS=${3}

# Uncomment to temporarily disable calls from fetch_jsons.sh script
# if [ "${4}" == "LOOP" ]; then exit; fi

if [[ "${MODE}" != "TEST" && "${MODE}" != "REAL" ]]
then
    echo "Usage: tcbot.sh MODE JSON DAYS [LOOP], MODE must be TEST or REAL"
    exit
fi

thirteendigitstring="^[0-9]{13}$"
if [[ ! ${JSON} =~ ${thirteendigitstring} ]]
then
    echo "Usage: tcbot.sh MODE JSON DAYS [LOOP], JSON must be 13 digits"
    exit
fi

digitstring="^[0-9]+$|^-[0-9]+$"
if [[ ! ${DAYS} =~ ${digitstring} ]]
then
    echo "Usage: tcbot.sh MODE JSON DAYS [LOOP], DAYS must be digits"
    exit
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
if [ ! -d ${SCRIPT_DIR}/${MODE} ]
then
    echo "Error: ${SCRIPT_DIR}/${MODE} doesn't exist"
else
    cd ${SCRIPT_DIR}/${MODE}
fi

if [ ! -f last_run_timestamp.txt ]
then
    echo -n $JSON > last_run_timestamp.txt
fi

# LASTRUN is the timestamp (in epoch seconds) that the bot calcuated the subs growth
# If the JSON passed to this script is named with a timestamp that's 24 hours later, it will calculate the subs growth again
# Otherwise, it'll just add the data to a text file for this period
read LASTRUN < <(head -n 1 last_run_timestamp.txt)

# The only fields from the JSON file that's required
fields=$(cat << EOF
___nsfw: .nsfw, 
___sus: .isSuspicious, 
___name: .name, 
___instance: .baseurl, 
___title: .title, 
___subs: .counts.subscribers, 
___time: .time, 
___posts: .counts.posts
EOF
)

jq ".[] | {$fields}" ${SCRIPT_DIR}/REAL/json_lemmy/${JSON}.json > /tmp/stripped.json

# jq can get this data more eloquently, but it's slower and titles need sanitising for backslashes anyway
grep '\"___nsfw\":' /tmp/stripped.json | sed 's/"___nsfw": //;s/,//' > /tmp/nsfw.txt                                  # true/false
grep '\"___sus\":' /tmp/stripped.json | sed 's/"___sus": //;s/,//' > /tmp/sus.txt                                     # true/false
grep '\"___name\":' /tmp/stripped.json | sed 's/"___name": //;s/,//;s/"//g;s/ //g' > /tmp/name.txt                    # community = name@instance
grep '\"___instance\":' /tmp/stripped.json | sed 's/"___instance": //;s/,//;s/"//g;s/ //g' > /tmp/instance.txt        # community = name@instance
grep '\"___title\":' /tmp/stripped.json | sed 's/"___title": //;s/,$//;s/"//g;s:\\$::' > /tmp/title.txt               # community header
grep '\"___subs\":' /tmp/stripped.json | sed 's/"___subs": //;s/,//' > /tmp/subs.txt                                  # subscribers
grep '\"___time\":' /tmp/stripped.json | sed 's/"___time": //;s/,//;s/"//g' > /tmp/time.txt                           # timestamp
grep '\"___posts\":' /tmp/stripped.json | sed 's/"___posts": //;s/,//' > /tmp/posts.txt                               # posts

paste -d "@" /tmp/name.txt /tmp/instance.txt > /tmp/community.txt
paste /tmp/nsfw.txt /tmp/sus.txt /tmp/community.txt /tmp/time.txt /tmp/subs.txt /tmp/posts.txt /tmp/title.txt >> ${LASTRUN}.txt

# Uncomment to limit to a particular community / instance 
#grep '\spiracy@lemmy.ml\s' ${LASTRUN}.txt > /tmp/${LASTRUN}.txt
#grep '@lemmy.world\s' ${LASTRUN}.txt >> /tmp/${LASTRUN}.txt 
#mv /tmp/${LASTRUN}.txt ${LASTRUN}.txt

GAP=$(( ${JSON}-${LASTRUN} ))

if [ ! ${GAP} -gt 82800000 ]
then 
    if [ "${MODE}" == "TEST" ]; then echo "Gap between JSONs is less than 24 hours, adding data to ${LASTRUN}.txt"; fi  
    exit
fi

# gap is more than 23 hours, last_run_timestamp is updated to now, and new text file initialised with data from this JSON
echo -n ${JSON} > last_run_timestamp.txt
paste /tmp/nsfw.txt /tmp/sus.txt /tmp/community.txt /tmp/time.txt /tmp/subs.txt /tmp/posts.txt /tmp/title.txt > ${JSON}.txt

# for a given community, the text file will look like:
# FALSE FALSE AAAA@instance TIME-CRAWLED SUBS POSTS TITLE
# ...
# FALSE FALSE AAAA@instance TIME-CRAWLED SUBS POSTS TITLE
# ...
# FALSE FALSE AAAA@instance TIME-CRAWLED SUBS POSTS TITLE
# So sort it and condense it, to work with data that's more like:
# FALSE FALSE AAAA@instance LATEST-TIME-CRAWLED SUBS-NOW SUBS-BEFORE POSTS TITLE
# FALSE FALSE BBBB@instance LATEST-TIME-CRAWLED SUBS-NOW SUBS-BEFORE POSTS TITLE

echo "true true dummy 0 0 0 dummy" > sorted.txt
sort -k 3,3 -k 4,4rn ${LASTRUN}.txt | uniq >> sorted.txt
echo "" >> sorted.txt
if [ "${MODE}" == "REAL" ]; then rm ${LASTRUN}.txt; fi

echo -n "" > condensed.txt
pc=""; subs_before=0
while read nsfw sus community time subs posts title
do
    if [ "$pc" != "$community" ]
    then
        if [ "$_community" != "" ]
        then
            if [ "$_community" != "dummy" ]
            then
                echo "${_nsfw} ${_sus} ${_community} ${subs_now} ${subs_before} ${_posts} ${_title}" >> condensed.txt
            fi
            pc=${community}; subs_now=${subs}; _posts=${posts}                                      # top of list
       fi
    fi
    _nsfw=${nsfw}; _sus=${sus}; _community=${community}; subs_before=${subs}; _title=${title}       # bottom of list
done < sorted.txt
if [ "${MODE}" == "REAL" ]; then rm sorted.txt; fi

# split condensed into SAFE and NSFW communities
# also filters communities with less than 3 subscribers (mostly spam)
# also filters communities with less than 3 posts (mostly dead)
# also filters communities with more posts than subscribers (mostly fed by overly enthusiastic bots)

rm -f *_condensed.txt
while read nsfw sus community subs_now subs_before posts title
do
    if [[ "${sus}" == "false" && ${subs_now} -gt 2 && ${posts} -gt 2 && ${subs_now} -gt ${posts} ]]
    then
        if [ "${nsfw}" == "true" ]; then view="NSFW"; else view="SAFE"; fi
        echo ${community} ${subs_now} ${subs_before} ${posts} ${title} >> ${view}_condensed.txt
    fi
done < condensed.txt
if [ "${MODE}" == "REAL" ]; then rm condensed.txt; fi

# For SAFE_condensed.txt and NSFW_condensed.txt, calculate subs growth
# Percentage growth is weighted by Absolute growth so list isn't dominated by new communities
# Final display is actually:
# "Show 7-day average growth for Communities that had the most growth in the 24 hour period"
# This isn't the same as:
# "Show Communities with top 7-day rolling average growth"
# Because that list tends to stagnate, with fewer new entries, and it taking longer for de-trending Communities to disappear
# Whichever is chosen, though, it'll be unfair to some Communities 

rm -f *_growth.txt
for VIEW in {"NSFW","SAFE"}
do
    echo -n "" > ${VIEW}_growth.txt
    while read community subs_now subs_before posts title
    do
        absolute_growth=$(( ${subs_now}-${subs_before} ))
        if [ ${absolute_growth} -eq 0 ]
        then
            weighted_growth=0.00
        else
            percentage_growth=$(echo "(${absolute_growth}/${subs_before})*100" | bc -l)
            weighted_growth=$(echo "scale=2; (${percentage_growth}*${absolute_growth})/100" | bc | sed 's/^\./0\./' | sed 's/^0$/0\.00/')
        fi
        echo ${weighted_growth} ${community} ${subs_now} ${posts} ${title} >> ${VIEW}_growth.txt
    done < ${VIEW}_condensed.txt
    if [ "${MODE}" == "REAL" ]; then rm ${VIEW}_condensed.txt; fi

    PERIOD=$(date -d "${DAYS} days ago" +"%Y-%m-%d")
    mv ${VIEW}_growth.txt ${SCRIPT_DIR}/REAL/history/${VIEW}/${PERIOD}.txt

    cd ${SCRIPT_DIR}/REAL/history/${VIEW}
    
    # data0 is usually today, data6 is usually 6 days ago (this should probably be stored as an array)
    i=$(( ${DAYS} + 0 ))
    data0="$(date -d "$i days ago" +"%Y-%m-%d").txt"
    i=$(( ${DAYS} + 1 ))
    data1="$(date -d "$i days ago" +"%Y-%m-%d").txt"
    i=$(( ${DAYS} + 2 ))
    data2="$(date -d "$i days ago" +"%Y-%m-%d").txt"
    i=$(( ${DAYS} + 3 ))
    data3="$(date -d "$i days ago" +"%Y-%m-%d").txt"
    i=$(( ${DAYS} + 4 ))
    data4="$(date -d "$i days ago" +"%Y-%m-%d").txt"
    i=$(( ${DAYS} + 5 ))
    data5="$(date -d "$i days ago" +"%Y-%m-%d").txt"
    i=$(( ${DAYS} + 6 ))
    data6="$(date -d "$i days ago" +"%Y-%m-%d").txt"

    if [ "${MODE}" == "TEST" ]; then echo "$data0 $data1 $data2 $data3 $data4 $data5 $data6"; fi
    
    echo -n '' > /tmp/results_${VIEW}.txt
    display=0
    sort -rn ${data0} | while read growth community subs posts title
    do
        grep --no-messages "\s${community}\s" $data0 $data1 $data2 $data3 $data4 $data5 $data6 | sed 's/^.*\.txt://' > /tmp/history.txt
        
        depth=$(wc -l /tmp/history.txt) 
        if [ ${depth:0:1} -lt 7 ]; then continue; fi

        posts_last_week=0
        total="0.00"
        while read _growth _community _subs _posts _title
        do
            posts_last_week=$_posts
            if [ "${_growth}" == "0.00" ]; then continue; fi
            total=$(echo "scale=2; ${total}+${_growth}" | bc)
        done < /tmp/history.txt

        new_posts=$(( ${posts}-${posts_last_week} ))
        if [[ ${new_posts} -lt 2 || "$total" == "0.00" ]]; then continue; fi  

        average=$(echo "scale=2; ${total}/7" | bc | sed 's/^\./0\./')
        echo "$average $community $subs $posts $new_posts $title" >> /tmp/results_${VIEW}.txt
        display=$(( ${display}+1 ))
        if [ ${display} -eq 50 ]; then break; fi
    done
    cd ${SCRIPT_DIR}/${MODE}
    
    sort -rn -o /tmp/results_${VIEW}.txt /tmp/results_${VIEW}.txt

    # (this should be re-written, to not duplicate code)
    if [ "${MODE}" == "TEST" ]
    then
        echo "New Entries"
        while read growth community rest_of_line
        do 
            grep --silent "^${community}$" ${SCRIPT_DIR}/REAL/mentions.txt
            if [ $? -ne 0 ]
            then 
                echo "${growth} ${community} ${rest_of_line}"
            fi 
        done < /tmp/results_${VIEW}.txt
        echo "Previous Entries"
        while read growth community rest_of_line
        do 
            grep --silent "^${community}$" ${SCRIPT_DIR}/REAL/mentions.txt
            if [ $? -eq 0 ]
            then 
                echo "${growth} ${community} ${rest_of_line}"
            fi    
        done < /tmp/results_${VIEW}.txt
        
        continue
    fi

    # Only at this point if MODE is REAL
    
    new_entries="##### New Entries"
    old_entries="##### Previously featured\n\n"
    while read growth community subs posts new_posts title
    do
        baseurl=" [\`${community#*@}\`]"
        if [ "${baseurl}" == " [\`lemmy.world\`]" ]; then baseurl=""; fi
        if [ "${baseurl}" == " [\`lemmynsfw.com\`]" ]; then baseurl=""; fi
        grep --silent "^${community}$" mentions.txt		
        if [ $? -ne 0 ]
        then
            echo $community >> mentions.txt     												
			new_entries="$new_entries\n\n""[${title}](/c/${community})${baseurl}, up ${growth}% to $subs, (${posts} posts, ${new_posts} recent)"
        else
	 		old_entries="$old_entries""[$title](/c/$community)${baseurl}, up $growth% to $subs, (${posts} posts, ${new_posts} recent)    \n"
		fi
    done < /tmp/results_${VIEW}.txt
	
    body="$new_entries\n\n${old_entries}\nResults are averaged over the past 7 days" 

    read community_id < <(head -n 1 community/${VIEW}_id.txt)
    read jwt < <(head -n 1 logins/${VIEW}_jwt.txt)

    DaySuffix() {
        case `date +%d` in
           01|21|31) echo "st";;
           02|22)    echo "nd";;
           03|23)    echo "rd";;
            *)       echo "th";;
        esac
        }
    today=$(date "+%A %e`DaySuffix` %B %Y")
    if [ "${VIEW}" == "NSFW" ]; then edition=" (NSFW edition)"; else edition=""; fi
    name="Trending Communities for ${today}${edition}"

    API="api/v3"
    end_point="post"

    read instance nsfw < <(head -n 1 community/${VIEW}_details.txt)

    json_data="{\"auth\":\"$jwt\",\"name\":\"$name\",\"community_id\":$community_id,\"nsfw\":$nsfw,\"body\":\"$body\"}"
    url="$instance/$API/$end_point"
    
    curl -L -H "Content-Type: application/json" -d "$json_data" "$url"
done


