#!/bin/ksh

export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/opt/VRTS/bin
ha_snap_file=/var/tmp/hastatus-sum.out
vcs_components="vxfen gab llt"
vcs_running=false
non_service_groups="clusterservice|network"

ACTION=${1-NONE}

if [[ ${ACTION} == "NONE" ]]; then
	echo "===> No action taken due to NONE action"
	exit 0
fi

if_vcs_running(){
	## exitCode: 0 - had and hashadow running
	## exitCode: 1 - had and/or hashadow not running. 
	[ $(pgrep '^(had|hashadow)$' |wc -l) -eq 2 ] && return 0 || return 1
}

if_services_offline(){
	## If any servicable (non-operational) SG running on host.
	## exitCode : 0 - There is no any operational service group online on server.
	## exitCode : 1 - Some service groups still ONLINE or PARTIAL on host.
	hagrp -state -sys `uname -n` |egrep -vi ${non_service_groups} |awk '
	!/^#/ {
			sg=$1;
			state=$4
			if(state!="|OFFLINE|"){
					groups[state]=groups[state]"\n"sg
					intervention++
				}
			}
			END{
					exitCode=0
					if(intervention!=0){
							print "Manual intervention required"
							exitCode=1
					        for(g in groups){
						    	if(g!="|OFFLINE|"){
							    		printf("Following groups in %s state. \n%s\n",g,groups[g])
							    }
					    }
                    }
					exit exitCode
			}'
}

stop_vcs(){
	## Stop VCS daemons
	hastop -local -noautodisable 
	while ! if_vcs_running; do
		printf "."
		sleep 4
	done
	printf "\nINFO. VCS stopped\n"
	stop_services $vcs_components
}

stop_services(){
	
	[ $# -lt 1 ] && exit 1
	uname=$(uname)
	for s in $@
	do
		case $uname in
			Linux) 
				if service $s status >/dev/null 2>&1; then
					service $s stop
				else
					continue
				fi
			;;
			
			SunOS)
				vers=$(uname -r |awk -F"." '{print $2}')
				case $vers in 
					10)
						svcadm disable -t system/${s}
					;;

					*)
						/etc/init.d/${s} stop
					;;
				esac
			;;

			*)
			;;
		esac
	done
}

while getopts s opts
do
	case $opts in 
		s) stop_option=true
		;;
		*) print "WARNING. Unrecognized option used"
		;;
	esac
done

if ! if_vcs_running; then
	print "INFO. VCS not running on host, skipping vcs steps."
	exit 0
fi
	
## Notice down status of VCS resources before stop
if if_services_offline; then
	print "INFO. No Services running on host, stopping VCS."
	hastatus -sum > $ha_snap_file
	stop_vcs
elif [[ $stop_option == "true" ]] ;then 
	print " (stop) -s option used. Skipping previous WARNING"
	print "INFO. Stopping VCS and running service groups"
	hastatus -sum > $ha_snap_file
	stop_vcs
else
	print 'WARNING. Some VCS stuff running on host, should be stopped first'
	exit 1
fi
