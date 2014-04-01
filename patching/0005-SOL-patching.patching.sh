#!/bin/ksh

ACTION=${1-NONE}

if [[ ${ACTION} == "NONE" ]]; then
	echo "===> No action taken due to NONE action"
	exit 0
fi

remove_webmin(){
    pkgs=$(pkginfo | awk '/webmin/ {print $2}')  ; echo $pkgs
    if [ ! -z $pkgs ]; then
        print "INFO. Removing webmin packages: $pkgs"
        pkgrm $pkgs
        unset pkgs
    fi
}

install_patches(){
    patches=/var/tmp/patches
    $patches/pca --install -y --patchdir=$patches --patchurl=http://scohomeserv/cgi-bin/pca-proxy.cgi
    unset patches
}

remove_webmin
install_patches
