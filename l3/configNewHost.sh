usage() {
	cat <<-EOF
	Usage: $0 [OPTIONS] <username@ip> <alias>
	NAME 
		$0 - copies dotfiles to target mashine
	SYNOPSIS
		$0 [OPTIONS] <username@ip> <alias>
	DESCRIPTIONS
		-h help
EOF
}

[ $# -ne 2 ] && usage && exit1
user_name=$(echo $1 |awk -F"@" '{print $1}')
ip=$(echo $1 |awk -F"@" '{print $2}')
alis=$2

[ -t config ] && echo -e "Host ${alis}\nHostName ${ip}\nUser ${user_name} >> config" || echo -e "Host ${alis}\nHostName ${ip}\nUser ${user_name}" >> config && echo the config file has been created

dot_files_copy() {
[ -t .vimrc ] && echo .vimrc copied || echo .vimrc doent exist 
[ -t .bashrc ] && echo .bashrc copied || echo .vimrc doent exist 
}

dot_files_copy
