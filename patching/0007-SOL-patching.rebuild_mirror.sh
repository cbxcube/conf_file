#!/bin/ksh

PATH=$PATH:/usr/sbin:/bin:/sbin:/usr/bin; export PATH

ACTION=${1-NONE}

if [[ ${ACTION} == "NONE" ]]; then
	echo "===> No action taken due to NONE action"
	exit 0
fi

rebuild_mirror(){
  mirror=$1
  REBUILD_CONFIG=/var/tmp/.rebuild_mirrors
  if [ -f $REBUILD_CONFIG ]; then
    submirror=$(nawk -v mirror=${mirror} '$1==mirror {if($2~/^d/) print $2}; ' $REBUILD_CONFIG)
    metattach $mirror $submirror
    unset mirror submirror
  else
    ## different scenario with guessing by size
    continue
  fi
}

get_md_by_fs(){
  [ $# -ne 1 ] && return 1
  fs=$1
  df -k $fs |nawk 'NR>1 {
      split($1,md,"/"); 
      if(md[3]=="md") { 
        print md[5] } 
        }'
  unset fs
}
check_md_states(){
  metastat |nawk -F": ?" '/Mirror/ {
      m=$1};
      /Submirror [0-9]/ {
          subm=$2;
          getline;
          subm_state=$2;
          if(subm_state~"Okay"){
              ok[m]+=1
          }
          else{
              n_ok[m]+=1
          }
      }
      END{
          result=0
          for(i in ok) {
              if(ok[i]>1){
                  printf("INFO. %s has %d submirrors in OK state\n",i,ok[i])
              }
              else{
                  result+=1
                  printf("CRITICAL. %s has only %d submirrors in OK state and %d needs maintenance\n",i,ok[i],n_ok[i])  > "/dev/stderr"
              }

          }
          exit result
  }'
}


for fs in / /var
do
  md=$(get_md_by_fs $fs)
  rebuild_mirror $md && print "INFO. $md being rebuilt" 
done
while ! check_md_states >/dev/null 2>&1
do
    sleep 30
    printf .
done
printf "\nINFO. Disk resyncing completed with success\n"
rm $REBUILD_CONFIG
