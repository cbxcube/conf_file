user=$1

ldapsearch -xWLLL -b 'dc=sssl,dc=bskyb,dc=com' -h ldaplive -p 389 uid=$user  cn
ldapsearch -xWLLL -b 'ou=netgroup,dc=sssl,dc=bskyb,dc=com' -h ldaplive -p 389 "(nisNetgroupTriple=\28,$user,bskyb.com\29)" cn
