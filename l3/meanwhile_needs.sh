#!/bin/bash

COMMANDS="uname -a; whoami"
HOSTS_LIST="/home/kab21/l3/list_of_hosts"
for host in $(cat $HOSTS_LIST)
do
  echo CURRENT is $host
  echo ===========================	
  ssh $host "$COMMANDS"
  done
