#!/usr/bin/env ksh


PATH=$PATH:/usr/sbin/
HOSTNAME=$(uname -n)
VXFS_FSTYP=/opt/VRTS/bin/fstyp
ERROR=0
case `uname` in
    Linux) AWK=gawk ;;
    SunOS) AWK=nawk ;;
    *)     AWK=awk ;;
esac

usage(){
    print "Usage: `basename $0` /file/system"
    exit 1
}

func_usage(){
    print "Wrong number of arguments passed to func"
    exit 1
}

get_dev_name(){
    [[ $# -ne 1 ]] && func_usage
    fs=$1
    dev=$(df -Ph ${fs} |$AWK 'NR!=1 {print $1}')
    print $dev
    unset dev fs 
}

get_mp_name(){
    [[ $# -ne 1 ]] && func_usage
    fs=$1
    mp=$(df -Ph ${fs} |$AWK 'NR!=1 {print $NF}')
    print $mp
    unset mp fs
}

if_vxfs(){
    ## Read and check arguments
    [[ $# -ne 1 ]] && func_usage
    
    dev=$1
    ## $1 can be mount dir or device
    fstype=$(${VXFS_FSTYP} ${dev} 2>/dev/null)
    [[ $fstype != "vxfs" ]] && exitCode=1 || exitCode=0
    unset fstype dev
    return $exitCode
}

get_dg_name(){
    [[ $# -ne 1 ]] && func_usage
    dev=$1
    print $dev|$AWK -F/ '{print $5}'

    unset dev
}

get_vol_name(){
    [[ $# -ne 1 ]] && func_usage
    dev=$1
    print $dev|$AWK -F/ '{print $6}'
    unset dev
}

maxgrow_by(){
    [[ $# -ne 2 ]] && func_usage
    _dg=$1
    _vol=$2
    vxassist -g ${_dg} maxgrow ${_vol} |$AWK '/can be extended by/ {print $7}'

    unset _dg _vol
}

verify_cluster_mode(){
	exitCode=1
	cluster_mode=$(vxdctl -c mode |$AWK  '/^mode/ {print $4}')
	if [[ ${cluster_mode} == "active" ]]; then
		## Determine which node is master for clustered volumes
		master_node=$(vxdctl -c mode |$AWK  '/^master/ {print $2}')
		exitCode=0
		print "INFO. vxdctl clustered mode is active"
		if [[ ${HOSTNAME} == ${master_node} ]]; then
			print "INFO. This is master node for vxvm"
		else
			print "WARNING. Master node for vxvm is ${master_node}"
		fi
	fi	
	return $exitCode
}

cfs_show_primary(){
	[[ $# -ne 1 ]] && func_usage
	typeset -i exitCode=1
	_fs=$1
	primary_node=$(fsclustadm -v showprimary ${_fs} 2>/dev/null)
	case $? in 
		0)
			exitCode=0
			print "INFO. Filesystem ${_fs} clustered"	
			[[ ${primary_node} == ${HOSTNAME} ]] && { print "INFO. This is primary node for vxfs"; } || print "WARNING. This is not primary node for clustered filesystem ${_fs} "
		;;
		19)
			print "INFO. Filesystem ${_fs} not clustered"
			exitCode=1
		;;
		*)
			print "Unknown return code for fsclustadm"
            exitCode=1
		;;
	esac
	unset _fs
	return $exitCode
}

get_first_vol_disk(){
    [[ $# -ne 2 ]] && func_usage
    _dg=$1
    _vol=$2
    ## Get first occured disk in volume for similarity
    _disk=$(vxprint -g ${_dg} |$AWK -v vol=${_vol} '$1=="v" {if($2==vol) R_VOL=1; else R_VOL=0}; $1=="dm" {disk[$2]=$3}; $1=="sd" {if(R_VOL==1) {gsub("-.*","",$2); print  disk[$2]; exit 0}}')
    print "INFO. You should request disk similar to ${_disk}"
    unset _dg _vol _disk
}

show_vvr_settings(){
    [[ $# -ne 1 ]] && func_usage
    [[ $(pgrep vradmind |wc -l) -lt 1 ]] && { print "INFO. No VVR daemon running."; return 1; }
    _dg=$1
    print "INFO. VVR daemon running on ${HOSTNAME}"
    vr_out=$(vradmin -g ${_dg} printrvg)
    [[ $? -ne 0 || -z ${vr_out} ]] && { print "INFO. No RVG replication set up for ${_dg} "; return 1; }
    print "${vr_out}" |$AWK '
        /^Primary/ {pri=1}
        /^Secondary/ {pri=0}
        /HostName/ {if(pri==1) primary=$2; else slave=$2}
        /datavol_cnt/ {vol_cnt=$2}
        /DgName/ {dg=$2}
        END {
            printf("WARNING. Disk group %s replicated with VVR from %s ==> %s\n",dg,primary,slave)
        }'
    return 0
}

[[ $# -ne 2 ]] && usage

fs=$1
grow_size=$2
typeset -i available_grow
mp=$(get_mp_name ${fs})
dev_name=$(get_dev_name ${fs})

if_vxfs $dev_name && { print "INFO. $fs is vxfs filesystem."; } || { print "$fs is not vxfs!"; exit 1; }

dg=$(get_dg_name $dev_name)
vol=$(get_vol_name $dev_name)
cfs_show_primary ${mp} && verify_cluster_mode  
show_vvr_settings ${dg}

available_grow=$(maxgrow_by $dg $vol)
if [[ $available_grow -lt $grow_size ]]; then 
    print "WARNING. Not enough space to extend fs"
    get_first_vol_disk $dg $vol
    exit 1
else
    print "INFO. $fs can be extended based on existant disks (${available_grow} available sectors ). "
fi

