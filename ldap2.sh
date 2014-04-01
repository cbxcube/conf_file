usage() {
        cat
	echo usage: `basename $0` '[-ng] [-suC] [-suU] [-uid] [-h] 
        [option ...]' 1>&2
   
}

case "$1" in 
	'-ng' )
		ldapsearch -xWLLL -D 'uid=kab21,ou=people,dc=bskyb,dc=com' -b 'dc=bskyb,dc=com' -h amsldapm10 -p 389 "cn=$2" cn nisNetgroupTriple
	;;
	'-suC' )
		ldapsearch -xWLLL -D 'uid=kab21,ou=people,dc=bskyb,dc=com' -b 'dc=bskyb,dc=com' -h amsldapm10 -p 389 "sudoCommand=$2" cn
	;;
	'-suU' )
		ldapsearch -xWLLL -D 'uid=kab21,ou=people,dc=bskyb,dc=com' -b 'dc=bskyb,dc=com' -h amsldapm10 -p 389 "sudoUser=$2" cn
	;;
	'-h' )
		usage
	;;
	'-uid' )
		ldapsearch -xWLLL -D 'uid=kab21,ou=people,dc=bskyb,dc=com' -b 'dc=bskyb,dc=com' -h amsldapm10 -p 389 uid=$2 cn
	;;
	\? )
		usage
	;;
	* )
		usage
	;;
esac
