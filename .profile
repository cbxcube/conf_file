export PATH=~kab21/bin:~kab21:$PATH:/sbin:/usr/sbin:/usr/bin:/usr/local/bin:/usr/local/sbin:/usr/symcli/bin:/opt/VRTS/bin:/etc/vx/bin:/usr/openv/netbackup/bin:/usr/openv/netbackup/bin/admincmd:/admin/dev/bin

bash
case `uname` in
  SunOS|OpenBSD)
    . ~kab21/.kshrc
  ;;
esac
