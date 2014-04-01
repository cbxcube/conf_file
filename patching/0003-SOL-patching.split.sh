#!/bin/ksh

PATH=$PATH:/bin:/sbin:/usr/sbin:/usr/bin; export PATH
AWK=/bin/nawk
MKDIR=/usr/bin/mkdir

ACTION=${1-NONE}

if [[ ${ACTION} == "NONE" ]]; then
	echo "===> No action taken due to NONE action"
	exit 0
fi

set -A MAIN_FS / /var
typeset -i err=0

backup(){
    BACKUP=backup  
    FILES=/etc/vfstab /etc/system 
    for file in $FILES
    do
        cp -p ${file}{,.$BACKUP} && echo "WARNING. Failed to create backup for ${file}" && echo "INFO. Backup for ${file} ${file}.${BACKUP}"
    done
}

get_mirr_dev_path(){
  ## read OBP variable nvramrc and looks for defined devalias rootmirror
  eeprom nvramrc |$AWK  '
    BEGIN {RS="="} 
    NR==2 {
    split($0,lines,"\n")
    err=1
    for(l in lines) { 
      if(lines[l]~/devalias rootmirror/) {
        err=0
        split(lines[l],disk)
        sub("disk","sd",disk[3])
        if(disk[3]~/^\/devices/)
          prefix=""
        else
          prefix="/devices"
        printf("%s%s\n",prefix,disk[3])
        } } 
    exit err  
    }'
}

dev_path_to_chardev(){
  ## $1 - Physical path to device
  ## Example: dev_path_to_chardev /pci@1c,600000/scsi@2/disk@0,0 
  ##          c1t1d0
  [ -z $1 ] && return 1
  dev_path=$1
  ls -l /dev/rdsk |$AWK -v dev_path=${dev_path} '$11~dev_path {sub("s.$","",$9); print $9; exit 0 }' && return 0 || return 1
}

get_meta_dev(){
    ## $1 - mount point, e.g. / 
    ## Example: get_meta_dev / 
    ##          d0 
    [ -z $1 ] && return 1
    FS=$1
    df -k $FS |$AWK 'NR>1 {
        if($1~/^\/dev\/md/){
          split($1,dev,"/"); 
          print dev[5]
          }
        else 
          exit 1
    }'
}
error_check(){
    if [ $err -ne 0 ];then
        echo "CRITICAL. Error detected on previous steps, exiting"
        exit $err
    fi
}
## Obtain required variables
obtain_settings(){
    RDEV=$(get_meta_dev /)
    VDEV=$(get_meta_dev /var)
    MIRR_DEV_PATH=$(get_mirr_dev_path) 
    MIRR_DEV=$(dev_path_to_chardev ${MIRR_DEV_PATH} )
    if [ -z ${MIRR_DEV} ];then
        if var=$(metastat -p $RDEV |$AWK '
        !/-m/ {
          disk[$1]=$4;
          total_sub+=1
        } END { 
        if(total_sub<2) 
          exit 1; 
        else {
        for(i in disk) 
          sub("s.$","",disk[i])
          print disk[i]
        } 
        }'); then
            MIRR_DEV=$(echo "${var}"|sort |tail -1)
        else
            echo "CRITICAL. Failed to determine rootmirror device"
            exit 1
        fi
        echo "WARNING. No device path found for mirror, using last device in sorted order ${MIRR_DEV} "
    fi
    RMIRDEV=$(metastat -p $RDEV |$AWK -v disk=${MIRR_DEV} '$4~disk {print $1}')
    VMIRDEV=$(metastat -p $VDEV |$AWK -v disk=${MIRR_DEV} '$4~disk {print $1}')
    RMIRSLICE=$(metastat -p $RMIRDEV|$AWK '{
        if($4~"^c.+t.+d.+s.+$"){ 
            disk=$4;
            }
        if ($4~"/dev/dsk/c.+t.+d.+s.+") {
            split($4,d,"/"); 
            disk=d[4]
            } 
        } END{print disk}')
    VMIRSLICE=$(metastat -p $VMIRDEV|$AWK '{
        if($4~"^c.+t.+d.+s.+$"){ 
            disk=$4;
            }
        if ($4~"/dev/dsk/c.+t.+d.+s.+") {
            split($4,d,"/"); 
            disk=d[4]
            } 
        } END{print disk}')
    for i in $MIRR_DEV_PATH $MIRR_DEV $RDEV $VDEV $RMIRDEV $VMIRDEV $RMIRSLICE $VMIRSLICE
    do
      if [ -z $i ];then 
        echo "CRITICAL. One of required variables not defined"
        exit 1
      fi
    done
}    
split_mirrors(){
    error_check
    REBUILD_CONFIG=/var/tmp/.rebuild_mirrors
    metadetach $RDEV $RMIRDEV && echo "INFO. Detached $RMIRDEV from $RDEV" || err=$err+1 
    metadetach $VDEV $VMIRDEV && echo "INFO. Detached $VMIRDEV from $VDEV" || err=$err+1
    [ -f $REBUILD_CONFIG ] && > $REBUILD_CONFIG
    echo "$RDEV $RMIRDEV" > $REBUILD_CONFIG
    echo "$VDEV $VMIRDEV" >> $REBUILD_CONFIG
}
update_detached_configs(){
    # mount splitted slice and alter fstab and system
    var_temp=/var/tmp
    mod_prefix=modified
    root_mirror_mount=${var_temp}/root_temp
    mirr_system_file=${root_mirror_mount}/etc/system
    mirr_vfstab_file=${root_mirror_mount}/etc/vfstab
    mirr_system_modified_file=${mirr_system_file}_${mod_prefix}
    mirr_vfstab_modified_file=${mirr_vfstab_file}_${mod_prefix}
    
    [ ! -d ${root_mirror_mount} ] && $MKDIR ${root_mirror_mount}
    
    mount /dev/dsk/${RMIRSLICE} $root_mirror_mount && echo "INFO. /dev/dsk/${RMIRSLICE} mounted to $root_mirror_mount" || err=$err+1
    error_check
    cp -p ${mirr_system_file} ${mirr_system_modified_file}
    cp -p ${mirr_vfstab_file} ${mirr_vfstab_modified_file}
    
    sed 's#^[ ]*rootdev#* COMMENTED AS BACKOUT FOR PATCHING rootdev#' ${mirr_system_file} > ${mirr_system_modified_file}
    mv ${mirr_system_modified_file} $mirr_system_file && echo "INFO. File ${mirr_system_file} updated"
    
    ## update vfstab. 
    $AWK -v RDEV=$RDEV -v RMIRSLICE=$RMIRSLICE -v VDEV=$VDEV -v VMIRSLICE=$VMIRSLICE   'BEGIN {
        MD_DSK="/dev/md/dsk/";
        MD_RDSK="/dev/md/rdsk/";
        DEV_DSK="/dev/dsk/";
        DEV_RDSK="/dev/rdsk/"
        }; 
        { 
        if ($1==MD_DSK""RDEV && $2==MD_RDSK""RDEV) {
            $1=DEV_DSK""RMIRSLICE
            $2=DEV_RDSK""RMIRSLICE
            print $0
        }
        else if($1==MD_DSK""VDEV && $2=MD_RDSK""VDEV) {
            $1=DEV_DSK""VMIRSLICE
            $2=DEV_RDSK""VMIRSLICE
            print $0
        }
        else { print $0 } 
    }' ${mirr_vfstab_file} > ${mirr_vfstab_modified_file}
    
    mv ${mirr_vfstab_modified_file} ${mirr_vfstab_file} && echo "INFO. File ${mirr_vfstab_file} updated"
    umount ${root_mirror_mount}
    rmdir ${root_mirror_mount}
}

obtain_settings
split_mirrors
update_detached_configs
