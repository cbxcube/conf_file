print_help() {
	cat <<- EOF
	Some text
	EOF
}

case ${1} in
	5 )
	print_help
	;;
	\? )
	print_help
	;;
	* )
 	echo good one
	;;
esac
