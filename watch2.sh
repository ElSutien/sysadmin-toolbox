#!/bin/bash

# $1 : var name of text
# $2 : line number from 1
getline () {
  printf '%s' "${!1}" | tail -n+$2 | head -n1
}

printheader () {
  local cols prefix suffix maxcmd header

  cols=$(tput cols)

  prefix="Interval: ${p_interval}s -- "
  suffix=" -- [$(date '+%H:%M:%S %d/%m/%Y')]"

  maxcmd=$((cols - ${#prefix} - ${#suffix}))

  if (( maxcmd > 3 )); then
      if (( ${#cmdline} > maxcmd )); then
          header="${prefix}${cmdline:0:maxcmd-3}...${suffix}"
      else
          header="${prefix}${cmdline}${suffix}"
      fi
  else
      header="${prefix}${suffix}"
      header=${header:0:cols}
  fi
  
  printf '%s' "$header"
}


p_interval=2
mode=0
declare -a cmd

while [ $# -gt 0 ]; do

  if [ $mode -eq 0 ]; then
    case $1 in
      --help)
      echo "Usage: watch2 [-n <interval>] [--] <command> <arg>"
      echo
      echo "Monitorize a command with colors and interactive terminal"
      exit 0
      ;;
      
      -n)
		  if grep -qE "[1-9][0-9]*" <<<"$2"; then
		    p_interval=$2
		    shift
		  else
		    echo "ERROR: interval not valid"
		    exit 2
		  fi
		  ;;
		  
		  -n*)
		  tmp=${1#-n}
		  if grep -qE "[1-9][0-9]*" <<<"$tmp"; then
		    p_interval=$tmp
		  else
		    echo "ERROR: interval not valid"
		    exit 2
		  fi
		  ;;
		  
		  --)
		  mode=1
		  ;;
		  
		  -*)
	    echo "ERROR: parameter not expected"
	    exit 1
	    ;;
	    
	    *)
		  [ $mode -eq 0 ] && mode=1
		  cmd+=("$1")
		  ;;
    esac
  
  else # [ $mode -eq 1 ]
  
		case $1 in
		  *)
		  cmd+=("$1")
		  ;;
		esac
  
  fi
  shift
done


printf -v cmdline '%q ' "${cmd[@]}"
flag=1
trap 'flag=0' SIGINT

tput smcup
#EXECUTION LOOP
while [ $flag -eq 1 ]; do
  #clear
  tput cup 0 0
  printheader
  tput el
  
  text=$(script -qefc "stty -onlcr; exec ${cmdline}" /dev/null |
  sed 's/\r$//')
  #${cmd[@]}
  tput cup 2 0
  
  cnt=1
  while IFS= read -r line; do
    oldline=$(getline textold $cnt)
    
    if [ ! "$line" == "$oldline" ]; then
      printf '%s' "$line"
      tput el
    fi
    printf '\n'
    cnt=$((cnt+1))
  done <<< "$text"

  tput ed
  
  textold="$text"
  sleep $p_interval
done
tput rmcup

exit 0
