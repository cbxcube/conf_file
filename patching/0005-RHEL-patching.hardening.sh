#!/bin/ksh

typeset -i errorCode=0

ACTION=${1-NONE}

if [[ ${ACTION} == "NONE" ]]; then
	echo "===> No action taken due to NONE action"
	exit 0
fi

cron_backup(){
	## Backup Cron files as they are being overwritten by hardening script
	for file in /etc/cron.allow /etc/at.deny /etc/cron.deny
	do
		if [ -f $file ]; then
			print "INFO. Copying file ${file} to ${file}.before-hardening. ${file} content: "
			cat $file
			cp -p $file ${file}.before-hardening
		fi
	done
}

cron_restore(){
	## Restore cron files
	for file in /etc/cron.allow /etc/at.deny /etc/cron.deny
	do
		if [ -f $file ]; then
			cp -p ${file}.before-hardening ${file} && print "INFO. Restored backed up copy of ${file}"
		fi
	done
}

hardening(){
	## PCI hardening steps
	CONFIGURE_HARDENING=/share/bbscripts/PRD/Host/Redhat/Build/ConfigureHardening/ConfigureHardening
	REMOVE_PCI_RPMS=/share/bbscripts/PRD/Host/Redhat/Remove/RemovePciRPMs/RemovePciRPMs
	[ -f $CONFIGURE_HARDENING ]
	[ -f $REMOVE_PCI_RPMS ]
	$CONFIGURE_HARDENING
	errorCode=$errorCode+$?
	$REMOVE_PCI_RPMS JDI=TRUE
	errorCode=$errorCode+$?
}

check_was(){
	## For WAS systems check if required perl modules installed.
	## This check already introduced to Hardening script, just double-check

	PERL_WAS_MODULES="perl-Convert-ASN1 perl-LDAP perl-XML-Twig"

	if_was_installed=$(chkconfig --list |awk '$1=="wasadm"'|wc -l)
	perl_modules_installed=$(rpm -q ${PERL_WAS_MODULES}|wc -l)
	if [ $if_was_installed -eq 1  ]; then
		if [ $perl_modules_installed -ne 3 ]; then
			print "INFO. After hardening one of perl modules: ${PERL_WAS_MODULES}  missing. Installing" 
			yum -y install $PERL_WAS_MODULES
		fi
	fi
}

## Main steps
cron_backup
hardening
check_was
cron_restore
