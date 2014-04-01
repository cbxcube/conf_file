HOSTNAME=$(uname -n)
PS1="${LOGNAME}@${HOSTNAME}$ "
if [ $LOGNAME = 'root' ]; then
  PS1="${LOGNAME}@${HOSTNAME}$ "
fi
export PS1

. ~diachens/.myshrc

alias !!='fc -e -'
alias sudo!!='sudo $(fc -ln -1 -1)'

# pushd / popd stuff

export integer DIRSTACKSIZE=0
export DIRSTACK=""
alias dirs='echo ${PWD} ${DIRSTACK}'

function pushd
{
  if [ $# -gt 1 ]; then
  echo "pushd:  Too many arguments." >&2
  return 1
  fi
  if [ "$1" = "" ]; then
  if [ ${DIRSTACKSIZE} -eq 0 ]; then
    echo "pushd:  No other directory." >&2
    return 1
  else
    cd $(echo ${DIRSTACK}' ' | cut -d' ' -f1) >&2 || return 1
    DIRSTACK="${OLDPWD} $(echo ${DIRSTACK}' ' | cut -d' ' -f2-)"
  fi
  elif [ "$(expr \"$1\" : \"+[0-9]*\")" -eq 0 ]; then
  cd $1 || return 1
  DIRSTACK="${OLDPWD} ${DIRSTACK}"
  (( DIRSTACKSIZE = DIRSTACKSIZE + 1 ))
  else
  index=${1#+}
  if [ ${index} -gt ${DIRSTACKSIZE} ]; then
    echo "pushd:  Directory stack not that deep." >&2
    return 1
  fi
  if [ ${index} -le 0 ]; then
    echo "$1:  No such file or directory" >&2
    return 1
  fi
  cd $(echo ${DIRSTACK}' ' | cut -d' ' -f${index})
  if [ ${index} -eq 1 ]; then
    DIRSTACK="$(echo ${DIRSTACK}' ' | cut -d' ' -f2-) ${OLDPWD}"
  else
    (( rightcut = ${index} + 1 ))
    (( leftcut = ${index} - 1 ))
    DIRSTACK="$(echo ${DIRSTACK}' ' | cut -d' ' -f${rightcut}-) ${OLDPWD} $(echo ${DIRSTACK}' ' | cut -d' ' -f1-${leftcut})"
  fi
  fi
  echo ${PWD} ${DIRSTACK}
  return 0
}

function popd
{
  if [ $# -gt 1 ]; then
    echo "popd:  Too many arguments." >&2
    return 1
  fi
  if [ "$1" = "" ]; then
    if [ ${DIRSTACKSIZE} -eq 0 ]; then
      echo "popd:  Directory stack empty." >&2
      return 1
    else
      cd $(echo ${DIRSTACK}' ' | cut -d' ' -f1)
      DIRSTACK="$(echo ${DIRSTACK}' ' | cut -d' ' -f2-)"
      (( DIRSTACKSIZE = DIRSTACKSIZE - 1 ))
    fi
  elif [ "$(expr \"$1\" : \"+[0-9]*\")" -eq 0 ]; then
    echo "popd:  Bad directory." >&2
    return 1
  else
    index=${1#+}
    if [ ${index} -gt ${DIRSTACKSIZE} ]; then
      echo "popd:  Directory stack not that deep." >&2
      return 1
    fi
    if [ ${index} -le 0 ]; then
      echo "popd:  Bad directory." >&2
      return 1
    fi
    if [ ${index} -eq 1 ]; then
      DIRSTACK="$(echo ${DIRSTACK}' ' | cut -d' ' -f2-)"
    else
      (( rightcut=${index} + 1 ))
      (( leftcut=${index} - 1 ))
      DIRSTACK="$(echo ${DIRSTACK}' ' | cut -d' ' -f1-${leftcut}) $(echo ${DIRSTACK}' ' | cut -s -d' ' -f${rightcut}-)"
    fi
    (( DIRSTACKSIZE = DIRSTACKSIZE - 1 ))
  fi
  echo ${PWD} ${DIRSTACK}
  return 0
}

