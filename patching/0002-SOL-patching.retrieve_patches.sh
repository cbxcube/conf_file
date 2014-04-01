#!/bin/ksh

PATH=$PATH:/usr/sbin:/bin:/sbin:/usr/bin:/usr/local/bin/; export PATH
AWK=/usr/bin/nawk

ACTION=${1-NONE}

if [[ ${ACTION} == "NONE" ]]; then
	echo "===> No action taken due to NONE action"
	exit 0
fi

REMOTE_PCA=/share/explorer/pca/pca
LOCAL_XREF_FILE=/var/tmp/patchdiag.xref

advise_fs() {
    typeset -i REQUIRED_SPACE=1024*1024 #1gb
    for fs in /var/tmp / 
    do
        df -k $fs |$AWK -v REQUIRED=${REQUIRED_SPACE} -v fs=$fs 'NR>1 {if($4<REQUIRED) {exit 1} else {print fs} }' && return 0
    done
    print "CRITICAL. No Suitable filesystem found for storing patches" >&2
    return 1

}

update_xref_file(){
    [ -f ${LOCAL_XREF_FILE} ] && rm -f $LOCAL_XREF_FILE
    $REMOTE_PCA --xrefurl=http://scohomeserv/cgi-bin/pca-proxy.cgi --patchurl=http://scohomeserv/cgi-bin/pca-proxy.cgi -l missing > /dev/null
    print "INFO. xref file $LOCAL_XREF_FILE updated"
    ## verify timestampts
    head -1 $LOCAL_XREF_FILE
}

dl_missing_patches(){
    DIR=$1
    PATCH_DIR=$DIR/patches
    LOG=$PATCH_DIR/download_log.out
    LOCAL_PCA=$PATCH_DIR/pca
    err=0
    [ ! -d $PATCH_DIR ] && mkdir $PATCH_DIR
    printf "" > $LOG
    ## Create local copy of PCA
    print "INFO. Copying pca from $REMOTE_PCA to $PATCH_DIR "
    cp -p $REMOTE_PCA $LOCAL_PCA || err=$err+1
    print "INFO. Downaloading patches to $PATCH_DIR. Logfile $LOG"
    ($LOCAL_PCA --download -y --patchdir=$PATCH_DIR --patchurl=http://scohomeserv/cgi-bin/pca-proxy.cgi missing >> $LOG ; echo $? > $PATCH_DIR/proc.pid ) & 
    child_proc=$!
    while kill -0 $child_proc 2>/dev/null
    do
        printf .
        sleep 10
    done
    child_exitcode=$(cat $PATCH_DIR/proc.pid) && rm $PATCH_DIR/proc.pid
    err=$err+$child_exitcode
    print ""
    tail -1 $LOG

    [ $err -eq 0 ] && print "INFO. Patches retrieved successfully" || print "CRITICAL. Error occured during patches retrieval" >&2
}

fs=$(advise_fs)
update_xref_file
dl_missing_patches $fs
