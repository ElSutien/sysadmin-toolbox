#!/bin/bash
checkip () {
  if [ "$1" == "--help" ]; then
    echo "CheckIP Usage:"
    echo "  checkip <ipaddr> [interval]"
  fi
  local addr="$1"
  local slp
  local ret
  local ccl=0
  [ -z "$2" ] && slp=2 || slp=$2
  tput smcup
  trap 'tput rmcup; trap - SIGINT SIGTERM SIGKILL; stty echo; return' SIGINT SIGTERM SIGKILL
  stty -echo
  clear
  tput cup 0 0
  
  while /bin/true; do
    trap 'echo hola' SIGTERM
    ping -W 2 -c 1 $addr 1>/dev/null 2<&1
    ret=$?
    tput cup 0 0
    [ $ccl -eq 10 ] && clear || ccl=$((ccl+1))
    date "+[ %d/%m/%Y %H:%M:%S ]             "
    echo -n "Host: $addr  "
    if [ $ret -eq 0 ]; then
      printf "\033[1;32mALIVE\033[0m   \n"
    else
      printf "\033[1;31mDEAD\033[0m   \n"
    fi
    sleep $slp
  done
}

checkip $*