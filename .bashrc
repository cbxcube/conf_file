export PS1="\u@\h$ "

if [ $LOGNAME = 'root' ]; then
  export PS1="\u@\h$ "
fi

. ~kab21/conf_file/.myshrc

