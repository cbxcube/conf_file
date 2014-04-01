#!/bin/ksh

ACTION=${1-NONE}

if [[ ${ACTION} == "NONE" ]]; then
	echo "===> No action taken due to NONE action"
	exit 0
fi

harden_os(){
    install_jass=/share/bbscripts/PRD/Host/Solaris/Build/InstallJASS/InstallJASS
    [ -f $install_jass ]
    $install_jass
}

harden_os
