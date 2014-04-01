#!/bin/ksh

OS_TYPE=$(uname)

## Set environment variables for different OS's. 
if [[ $OS_TYPE == "Linux" ]]; then
  DU=/usr/bin/du
  AWK=/bin/awk
elif [[ $OS_TYPE == "SunOS" ]]; then
  DU=/usr/xpg4/bin/du
  AWK=/usr/bin/nawk
else
  echo "Not adopted for ${OS_TYPE} yet"
  exit 2 
fi

## Set value to / in case not specified.
FS=${1:-/}

for dir in  $(ls $FS)
do
  if [[ $(df -k $FS/$dir 2>/dev/null|$AWK -v f="$FS" '$0!~/Filesys/ && $6==f' |wc -l) -eq 1 ]]; then 
    echo $FS/$dir
  fi
done | xargs $DU -xsk 2>/dev/null |sort -k 1,1n |$AWK '{total+=$1;a[i++]=$0} END {for (i=1;i<NR;i++) { split(a[i],s," "); percent=total/100; if(s[1]>percent) {print a[i] ;} } }'  ##This section need to be checked,but it is working on Lin
