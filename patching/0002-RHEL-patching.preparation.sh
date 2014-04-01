#!/bin/ksh

ACTION=${1-NONE}

if [[ ${ACTION} == "NONE" ]]; then
	echo "===> No action taken due to NONE action"
	exit 0
fi

fim_remove(){
	## FIM should be reinstalled to fit new kernel
	SOLIDCORE_PKG="solidcoreS3"
	CMA_PKGS="MFEcma MFErt"
    SOLIDCORE_INITD="/etc/init.d/scsrvc"
	if rpm -q $CMA_PKGS > /dev/null 2>&1 ;then
		service cma stop 2>/dev/null 
		rpm -e $CMA_PKGS
	else
		print "INFO. mcafee packages not installed"
	fi

	if rpm -q $SOLIDCORE_PKG > /dev/null 2>&1; then
		print "pass: solidcore(PRD) Solidcor3(PTT)"
		/usr/sbin/sadmin recover
		/usr/sbin/sadmin disable 
		service scsrvc stop 2>/dev/null
		rpm -e --noscripts $SOLIDCORE_PKG
        ## Remove remained link for solidcore at /etc/init.d 
        if [[ -h $SOLIDCORE_INITD ]];then
            unlink $SOLIDCORE_INITD && print "INFO. Removed remained link $SOLIDCORE_INITD"
        fi 
	else
		print "INFO. Solidcore package not installed"
	fi
}

run_explorer(){
	## Document current configuration
	EXPLORER=/share/bbscripts/PRD/Host/Redhat/Status/Explorer/Explorer
	## This line added to request file location and let automounter mount required dir before invoking explorer
	[ -f $EXPLORER ]
	$EXPLORER
}


fim_remove
run_explorer
