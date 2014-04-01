#!/bin/ksh

DOMAIN=$1
RULES_FILE=$2

[[ -z $RULES_FILE || ! -f $RULES_FILE ]]  && exit 1

while read head source destination flags
do
        source=$(print $source |sed 's#[\^\$\?]##g')
        res_destination=$(curl -I ${DOMAIN}${source} 2>/dev/null |awk  '/Location/ {print $2}'|tr -d '\r' )
        [[ $destination = $res_destination ]] && print SUCCESS || { 
            print FAIL; 
            printf "%-10s %s\n" Expected: $destination;
            printf "%-10s %s\n" Received: $res_destination
        }
done < $RULES_FILE

