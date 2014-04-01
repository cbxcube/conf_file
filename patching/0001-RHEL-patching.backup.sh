#!/bin/ksh
PATH=$PATH:/usr/sbin:/bin:/sbin:/usr/bin; export PATH
AWK=/bin/gawk

UNAME=$(uname -n)
BASEDIR=$(dirname $0)

ACTION=${1-NONE}

if [[ ${ACTION} == "NONE" ]]; then
	echo "===> No action taken due to NONE action"
	exit 0
fi

typeset -i err=0

check_errors(){
	if [ $err -ne 0 ];then
		print "FAIL. Exiting due to previous errors"
		exit 1
	fi
}

if_fs_lvm(){
	## usage:   if_fs_lvm /filesys
	## example: if_fs_lvm /
	## exit code: 0 - true, 1 - false
	if [ $# -lt 1 ];then
		print "wrong number of arguments passed to func"
		return 1
	fi
	fs=$*
	typeset -i result
	result=0
	for f in ${fs}
	do
		[ ! -d $f ] && return 1
		df -Pk $f |$AWK 'BEGIN {lvm_prefix="/dev/mapper/"}; 
			NR>1 { if($1!~lvm_prefix){
				exit 1
				} 
			}' || result=$result+1   
	done
	return $result
	unset fs result
}

if_lvm_exist(){
	## usage:	   if_lvm_exist lvname
	## example:	 if_lvm_exist apps
	## exit code:   0 - exist, 1 - doesn't exist
	if [ $# -lt 1 ];then
		print "wrong number of arguments passed to func"
		return 1
	fi
	lv_name=$1
    _lvdisplay=$(sudo lvdisplay -c)
	echo "$_lvdisplay"|$AWK -F: -v lv=${lv_name} 'BEGIN {res=1}; 
		{ split($1,dev_tree,"/")
		if(dev_tree[4]==lv) 
			res=0
		} END {exit res}'
	return $?

}

get_lvname(){
	## usage:	   get_lvname /filesys
	## example:	 get_lvname /		=>  lv_root
	## exit code:   0 - fs under lvm, 1 - fs is not under lvm;
	[ $# -ne 1 ] && return 1
	fs=$1
	if if_fs_lvm $fs;then
		df -Pk $fs |$AWK 'NR>1 {
			split($1,device,"/"); 
			split(device[4],lvname,"-"); 
			print lvname[2]
			}'
	else
		return 1
	fi
}

get_vgname(){
	[ $# -ne 1 ] && return 1
	fs=$1
	if if_fs_lvm $fs;then
		df -Pk $fs |$AWK 'NR>1 {
			split($1,device,"/"); 
			split(device[4],vgname,"-"); 
			print vgname[1]
			}'
	fi
}

get_vg_freespace(){
	[ $# -ne 1 ] && return 1
	vgname=$1
    _vgdisplay=$(sudo vgdisplay -c $vgname)
	echo "${_vgdisplay}"|$AWK -F: '{print $13*$16}' || return 1
	unset vgname
}

get_fs_size(){
	[ $# -ne 1 ] && return 1
	fs=$1
	df -Pk $fs |$AWK 'NR>1 {print $2}'
	return $?
	unset fs
}
get_fs_freespace(){
	[ $# -ne 1 ] && return 1
	fs=$1
	df -Pk $fs |$AWK 'NR>1 {print $3}'
	return $?
	unset fs
}
last_mount_time_fs(){
	## usage:   last_mount_time_fs /dev/mapper/fs
	## example: last_mount_time_fs /dev/mapper/VolGroup01-OSbackup   =>  1374483478  
	## exitCode:0 - success, 1-255 - failed.
	[ $# -ne 1 ] && return 1
	dev=$1
	rpm -q e2fsprogs >/dev/null 2>&1 
	e2fs_installed=$?
	if [ $e2fs_installed -eq 0 ]; then
		dumpe2fs $dev 2>/dev/null  |gawk -F": " '/Last mount time/ {print $2}' |date --utc  +%s
		return $?
	else
		return 1
	fi
}
lvm_backup(){
	## usage: lvm_backup filesystem
	## $1 - filesystem, e.g.: lvm_backup /
	[ $# -ne 1 ] && return 1
	f=$1
	if if_fs_lvm $f ; then
			print "INFO. Trying to use lvm_backup for back up $f"
			print "INFO. $f under lvm" 
			typeset -i snap_delta=524288
			typeset -i vg_free req_space req_space_delta
			COMPRESSION_COEF=0.70
			vg=$(get_vgname $f)
			lvm=$(get_lvname $f)
			lvm_os_backup=OSbackup
			os_mount_backup=/OSbackup
			dd_gz_file=${lvm}.gz
			lvm_snap=${lvm}_snap
			vg_free=$(get_vg_freespace $vg)
			fs_size=$(get_fs_size $f)
			req_space=${COMPRESSION_COEF}*${fs_size}
			req_space_delta=${req_space}+${snap_delta}
			dev_os_backup=/dev/${vg}/${lvm_os_backup}
			dev_fs=/dev/${vg}/${lvm}

			if [ ${vg_free} -gt ${req_space_delta} ];then
				print "INFO. Enough space in VG for snapshot backup"
				backup_type=local
				## proceed with LVM backup
				print "COMMAND. lvcreate -L ${snap_delta}k -s -n ${lvm_snap} ${vg}/${lvm}" && lvcreate -L ${snap_delta}k -s -n ${lvm_snap} ${vg}/${lvm}
				if  ! if_lvm_exist $lvm_os_backup ; then
					print "COMMAND. lvcreate -L ${req_space}k -n ${lvm_os_backup} ${vg}"  
					lvcreate -L ${req_space}k -n ${lvm_os_backup} ${vg} || err=$err+1
					print "COMMAND. mkfs -t ext3 ${dev_os_backup}" 
					mkfs -t ext3 ${dev_os_backup} >/dev/null || err=$err+1
					check_errors
				else
					print "COMMAND. +lvresize -L ${req_space}k ${dev_os_backup}" 
					lvresize -L +${req_space}k ${dev_os_backup} || err=$err+1
					print "COMMAND. e2fsck -y -f ${dev_os_backup}"
					e2fsck -y -f ${dev_os_backup} >/dev/null || err=$err+1
					print "COMMAND. resize2fs ${dev_os_backup}" 
					resize2fs ${dev_os_backup} || err=$err+1
					check_errors
				fi
				[ ! -d $os_mount_backup ] && mkdir $os_mount_backup
				if ! $AWK -v fs="${os_mount_backup}" 'BEGIN {res=1}; $2==fs {res=0} END{exit res}' /proc/mounts; then
					print "COMMAND. mount ${dev_os_backup} ${os_mount_backup}" 
					mount ${dev_os_backup} ${os_mount_backup}
				fi
	
				print "COMMAND. dd if=/dev/${vg}/${lvm_snap} bs=1M |gzip -c > ${os_mount_backup}/${dd_gz_file}"
				dd if=/dev/${vg}/${lvm_snap} bs=1M |gzip -c > ${os_mount_backup}/${dd_gz_file}  || err=$err+1
				print "COMMAND. lvremove -f ${vg}/${lvm_snap}" 
				lvremove -f ${vg}/${lvm_snap} || err=$err+1
				umount $os_mount_backup
				rmdir $os_mount_backup
				check_errors

			elif [ ${vg_free} -gt ${snap_delta} ]; then
				## use nfs to store snapshot
				backup_type=nfs
				typeset -i avail_space
				nfs_share="scohomeserv:/export/dump/patching/mondo"
				print "WARNING. Enough space for snapshot only, using $nfs_share location for storing $lvm_snap backup"
				[ ! -d $os_mount_backup ] && mkdir -p $os_mount_backup
				print "COMMAND. lvcreate -L ${snap_delta}k -s -n ${lvm_snap} ${vg}/${lvm}" 
				lvcreate -L ${snap_delta}k -s -n ${lvm_snap} ${vg}/${lvm} || err=$err+1
				print "COMMAND. mount -t nfs $nfs_share $os_mount_backup"
				mount -t nfs $nfs_share $os_mount_backup || err=$err+1
				[ ! -d ${os_mount_backup}/${UNAME} ] && mkdir ${os_mount_backup}/${UNAME}
				## check errors
				check_errors
				## check available space
				avail_space=$(get_fs_freespace $os_mount_backup) 
				if [ ${avail_space} -lt ${req_space_delta} ];then
					print "WARNING. Not enough disk space on NFS share $nfs_share"
					return 1
				fi
				print "COMMAND. dd if=/dev/${vg}/${lvm_snap} bs=1M |gzip -c > ${os_mount_backup}/${UNAME}/${dd_gz_file}"
				dd if=/dev/${vg}/${lvm_snap} bs=1M |gzip -c > ${os_mount_backup}/${UNAME}/${dd_gz_file}  || err=$err+1
				print "COMMAND. lvremove -f ${vg}/${lvm_snap}" 
				lvremove -f ${vg}/${lvm_snap}
				umount $os_mount_backup
				rmdir $os_mount_backup
				check_errors
			else
				backup_type=mondo 
				return 1
			fi
	  
	else	
		print "$f is not under LVM" >&2
		## use mondo to snap it
		return 1
	fi
	
}

mondo_backup(){
	## Pre-requisites installation
	yum -y install mkisofs cdrecord
	RPMDIR=/net/amsnfs/export/software/Software_Depot/Live/LnxSvrs/config/skysoe/RPMS
	RequiredFiles=${RPMDIR}/CreateMondoISO/RequiredFiles/5.x
	REQD_RPMS="mindi mindi-busybox mondo buffer afio"
	for MONDO_PKG in $REQD_RPMS
	do 
		rpm --nomd5 --nosignature -Uvh $RequiredFiles/RPMs/$MONDO_PKG*.rpm
	done
	
	## Set up required directories
	typeset -i REQUIRED_MONDO_SPACE
	EXCLUDE_STRING="/net|/apps|/ora|/mnt|/var/log|/share|/PTT|/PRD"
	ISOMNT=/var/tmp/isomnt
	NFS_DUMP=scohomeserv:/export/dump/patching/mondo
	REQUIRED_MONDO_SPACE=2*1024.1024 ## 2 Gb space required
	HIDIR=$ISOMNT/${UNAME}/mondo
	[ ! -d $ISOMNT ] && mkdir -p $ISOMNT
	mount $NFS_DUMP $ISOMNT 
	mkdir -p ${HIDIR}
	mkdir -p ${HIDIR}/tmp ${HIDIR}/scratch ${HIDIR}/run ${HIDIR}/iso
	nfs_avail_space=$(get_fs_freespace $ISOMNT)
	if [ $nfs_avail_space -lt $REQUIRED_MONDO_SPACE ]; then
		print "WARNING. Not enough for mondo space on $NFS_DUMP, required:  ${REQUIRED_MONDO_SPACE}kb "
		umount $ISOMNT
		return 1
	fi
	
	## Archive start as itself
	print "INFO. Mondo backup started. Image to be written to ${NFS_DUMP}/${UNAME}/mondo"
	nohup mondoarchive -O -i -p ${UNAME} -N -E "${EXCLUDE_STRING}" -d ${HIDIR}/iso -T ${HIDIR}/tmp -S ${HIDIR}/scratch -s 4480m |tee  ${HIDIR}/run/mondo-${UNAME}.output
	## -i - Use ISO files (CD images) as backup media.
	## -O - Backup your PC
	## -p - Use prefix to generate the name of your ISO images. 
	## -N - Exclude all mounted network filesystems (NFS,SMB, Coda, MVFS, AFS, OCSF).
	## -E - Exclude dir(s) from backup. The dirs should be separated with a pipe and surrounded by quotes.
	## -d - Specify the backup device (CD/tape/USB) or directory (NFS/ISO)
	## -S - Specify the full pathname of the scratchdir, directory where ISO images are built before being archive.
	## -s - How much can each of your backup media hold? 
	exitCode=$?
	
	umount $ISOMNT
}

boot_area_backup(){
	## backup boot options
	OS_BACKUP_DIR=/OSbackup
	mkdir ${OS_BACKUP_DIR}
	mount /dev/VolGroup00/OSbackup ${OS_BACKUP_DIR} > /dev/null 2>&1 || sudo mount -t nfs scohomeserv:/export/dump/patching/mondo ${OS_BACKUP_DIR}
	print "INFO. Backign up /boot dir"
	cd /boot; sudo tar -pczf ${OS_BACKUP_DIR}/${UNAME}_boot.tar.gz .  || err=$err+1
	umount ${OS_BACKUP_DIR}
	rmdir ${OS_BACKUP_DIR}
	check_errors
    print "INFO. /boot backed up successfully"
}

check_and_clean(){
	## remove old uncleaned devices, snapshots, directories and links
	osbackup_lv=OSbackup
	osbackup_dir=/OSbackup
	for fs in / /var
	do
		if if_fs_lvm $fs; then
			vg=$(get_vgname $fs)
			lv=$(get_lvname $fs)
            _lvdisplay=$(lvdisplay ${vg}/${lv})
			snapshot=$(echo "${_lvdisplay}"|awk '/LV snapshot/ {getline; print $1}')
			if lvdisplay -c ${vg}/${osbackup_lv} > /dev/null 2>&1; then
				# unmount and remove old backup lvm if it still exist
				umount -f /dev/${vg}/${osbackup_lv} > /dev/null 2>&1
				lvremove -f ${vg}/${osbackup_lv} && print "INFO. Old backup removed ${vg}/${osbackup_lv}" || err=$err+1
			fi
			if [[ ! -z ${snapshot} ]]; then
				lvremove -f ${snapshot} || err=$err+1
			fi
			unset vg lv snapshot _lvdisplay
		fi
	done
	# remove link to /OSbackup if exist
	if [[ -h $osbackup_dir ]];then
		unlink $osbackup_dir && print "INFO. Link $osbackup_removed" || { print "ERROR. Failed to remove link ${osbackup_dir}";  err=$err+1; }
	fi
	# remove /OSbackup directory if exist
	if [[ -d $osbackup_dir ]]; then
		rm -rf $osbackup_dir && print "INFO. Directory $osbackup_dir removed" || { print "ERROR. Failed to remove $osbackup_dir"; err=$err+1; }
	fi
	check_errors
}

## Main part
check_and_clean
typeset -i backed_up=0
lvm_backup / && backed_up=$(expr $backed_up + 1)
lvm_backup /var && backed_up=$(expr $backed_up + 1)
boot_area_backup

[ $backed_up -ne 2 ] && mondo_backup

#fi
