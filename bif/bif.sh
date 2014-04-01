usage() {
	cat <<- EOF
	Usage: $0 <sudoers_group>
	sudoers_group: Sudoers groups which should be checked
	test file contains info about users
	test1 file contain info about netgroups
	test2 file contain info about sudo Commands in mentioned sudo group
	EOF
	}
[ $# -eq 0 ] && usage && exit 1

while read user_id pri_group sec_group home_dir; do
if  id ${user_id} > /dev/null 2>&1
        then
                echo "[ $user_id ] exist"
                if  id ${user_id} | awk -F"(" '{print $3}' | grep ${pri_group} > /dev/null 2>&1
                        then
                                if id ${user_id} | grep ${sec_group} > /dev/null 2>&1
                                        then echo "[ $user_id ] secondary group correct"
                                        else echo "[ $user_id ] secondary group WRONG"
                                fi
                                echo "[ $user_id ] gid CORRECT"
                        else
                        echo "[ $user_id ] gid does NOT correct"
                fi
        else
        echo "[ $user_id ] does NOT exist"
fi
echo ----------------------------
done  < test

echo "Checking netgroups"

while read netgr; do
getent netgroup $netgr > /dev/null 2>&1 && echo "[ $netgr ] exist" || echo "[ $netgr ] SHOULD BE CREATED" 
echo "--------------------------"
done < test1

#while read netgr; do
#	if getent netgroup $netgr > /dev/null 2>&1
#	then
#		echo "[ $netgr ] exist" 
#	else 
#		 echo "[ $netgr ] SHOULD BE CREATED"
#	fi
#done < test1
echo "Cheching sudoers group and sudo commands"

sudo_check() {
if [ ! -z $1 ]
   then 
       ldapsearch -h upsds0g0 -x -D "cn=proxyAgent,ou=profile,dc=bskyb,dc=com" -w "pr0xyds61" -b "cn=$1,ou=sudoers,dc=bskyb,dc=com" cn > /dev/null 2>&1
        status=$?	   
		if [ $status -ne 0 ] 
			then echo "[ $1 ] DOES NOT EXIST"
			else
				echo "[ $1 ] EXIST"
				while read sudo_command; do
				sudo_search=$(echo $sudo_command | awk -F":" '{print $2}')
				ldapsearch -h upsds0g0 -x -D "cn=proxyAgent,ou=profile,dc=bskyb,dc=com" -w "pr0xyds61" -b "cn=$1,ou=sudoers,dc=bskyb,dc=com" sudoCommand | egrep -i "$sudo_search" > /dev/null  2>&1 && echo "[ $sudo_search ] PRESENT" || "[ $sudo_search ] MISS"
				done < test2
		fi
fi
}

until [ -z $1 ]; do
        sudo_check $1
        shift
done
