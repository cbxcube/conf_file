#!/bin/ksh

PATH=$PATH:/usr/sbin:/bin:/sbin:/usr/bin; export PATH
AWK=/bin/nawk

ACTION=${1-NONE}

if [[ ${ACTION} == "NONE" ]]; then
	echo "===> No action taken due to NONE action"
	exit 0
fi

if_md(){
  ## Check whether file system under svm control
  file_sys=$1
  if df -k ${file_sys} |awk 'NR>1 {
      split($1,dev_path,"/");
      if (dev_path[3]=="md") {
        exit 0
      } 
      else 
        exit 1
      }'
  then
    return 0
  else
    return 1
  fi
}

check_md_states(){
  metastat |$AWK -F": ?" '/Mirror/ {
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

validate_metadb(){
    metadb |$AWK -F'\t' 'NR>1 {
        dev=$NF;
        if (dev in replicas)
            {}
        else
            spreaded+=1
        replicas[dev]+=1
        if($1~/a.*u/){
          active_r[dev]+=1; }
        else bad_r[dev]+=1
      }
      END{
        result=1
        for(i in replicas)
        {
          if(bad_r[i]!=0){
              printf("WARNING. Corrupted replica on %s found\n",i)}
          if(active_r[i]>0)
              spreaded_ok+=1
        }
        if(spreaded_ok>1){
            printf("INFO. Active replicas spreaded across %d disks\n", spreaded_ok)
            result=0
        }
        else
            printf("CRITICAL. Up to date mdb replica stored only on %d disk\n",spreaded_ok) > "/dev/stderr" 
        exit result
    }'
}

check_obp_settings(){
    set -A keys use-nvramrc? auto-boot?
    set -A expected_re "true" "true"
    eeprom nvramrc |$AWK 'BEGIN{
        RS=EOF; 
        alias["root"]="devalias rootdisk"; 
        alias["mirr"]="devalias rootmirror"
      } NR==1 {
        for(i in alias){
            if(index($0,alias[i]) == 0) 
                printf("WARNING. nvramrc variable %s not defined\n",alias[i])
            else 
                printf ("INFO. nvramrc alias \"%s\" defined\n",alias[i])
        }
    }'
    for i in 0 1 
    do
            if eeprom ${keys[$i]} |egrep "${expected_re[$i]}$" >/dev/null 2>&1 ;then
                    print "INFO. eeprom  variables ${keys[$i]} is fine"
            else
                    print "WARNING. eeprom  variables ${keys[$i]} is incorrect"
                    result=$result+1
            fi
    done
    return $result
}

for fs in / /var
do 
    if if_md $fs; then
        print "INFO. $fs under SVM control"
    else
        print "CRITICAL. $fs is not metadevice" >&2
        exit 1
    fi
done

## Main part
check_md_states
validate_metadb
check_obp_settings
