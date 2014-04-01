DG_name=$1
size=$(vxassist -g $DG_name maxsize)
echo $size
#disks=$(vxdg -g $DG_name free |sed 1d |awk '{print $2}' |tr -s '\n' ' ' )
disks=$(vxdisk list | awk '/$DG_name/ {print $1}')

for i in ${disks} 
do
VOL_name=$(xiv_devlist -xt csv | egrep -i "$i" | awk -F,  '{print $4}')
echo $VOL_name
done
#XIV_name=$(/usr/bin/xiv_syslist -t csv | sed 1d | awk -F, '{print $1}' )
#echo $XIV_name
