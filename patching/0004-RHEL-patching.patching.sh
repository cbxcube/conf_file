#!/bin/ksh

typeset -i errorCode=0
# REPO_KEY="LATEST"

ACTION=${1-NONE}

if [[ ${ACTION} == "NONE" ]]; then
	echo "===> No action taken due to NONE action"
	exit 0
fi

check_errors(){
	if [ $errorCode -ne 0 ];then
		print "FAIL. Exiting due to previous errors"
		exit 1
	fi
}
usage(){
	print "usage: `basename $0` repo_key"
	exit 1
}
subscribe_spacewalk(){
	check_errors
	## Subscribe to correct Spacewalk with REPOKEY
	AIRLOCK=/share/bbscripts/PRD/Host/Redhat/Deploy/Airlock/Airlock
	## For automounter
	[ -f $AIRLOCK ]
	if [ $# -eq 1 ]; then
		REPO_KEY=$1
		$AIRLOCK SPACEWALKKEY=$REPO_KEY
	elif [ $# -eq 0 ];then
		REPO_KEY="LATEST"
		$AIRLOCK GLIBCWORKAROUND=1 SPACEWALKKEY=$REPO_KEY
	else
		$AIRLOCK $@
	fi

	unset AIRLOCK
}

yum_update(){
	check_errors
	## Main patching process.
	yum -y --nogpgcheck --exclude oracle* --exclude jdk* --exclude VRTSsfmh* update
	errorCode=$errorCode+$?
}

fix_sudoers(){
	## During patching from 5.1 to higher versions nsswitch.conf overwritten
	check_errors
	NSSWITCH_CONF=/etc/nsswitch.conf
	grep sudoers $NSSWITCH_CONF && print "INFO. sudoers entry exist in ${NSSWITCH_CONF}" || print 'sudoers:	   ldap' >> $NSSWITCH_CONF
}

## Read arguments
[[ $# -eq 1 ]] && REPO_KEY=$1 || usage

## Main part
subscribe_spacewalk $REPO_KEY
yum_update
fix_sudoers
