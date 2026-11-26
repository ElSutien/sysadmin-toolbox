#!/bin/bash

VERSION="1.0"
RELEASE_DATE="25/11/2026"
AUTHOR="ElSutien"


# Check needed dependencies for execution
checkDependencies () {
  local dependecies="grep script tcpdump"
  local res=0 x
  for x in $dependencies; do
    which $x 1>/dev/null 2>&1 || error "Dependencies not met for '$x'" exit 5
  done
}

# FUNCTION Print an error message to stderr with color
# Parameters:
#   - 1*: str Message to print
# Stderr: Printed message with colors
# Date: 30/10/20226
perror () {
  [ -t 2 ] && local CNC="\033[0m" CRED="\033[1;31m" || local CNC= CRED=
  echo -e "${CRED}ERROR: ${@}${CNC}" 1>&2
}

# FUNCTION Print an error message and perform an action
# Parameters:
#   - 1 : str Message to print
#   - 2*: str Command and attributes to execute after print
# Stderr: Printed message with colors
# Date: 30/10/20226
error () {
  perror "${1}"
  shift
  [ $# -gt 0 ] && { eval $@; return $?; }
}


#########################################################################################
# Clize Version 1.2 (30/10/2026)


__clizepipe_one () {
  local red='1;31'
  local green='1;32'
  local yellow='1;33'
  local blue='1;34'
  local purple='1;35'
  local cyan='1;36'
  GREP_COLORS="ms=${!1}" grep --line-buffered --color=always -E "$|${2}"
}

__clizepipe () {
  [ "$#" -eq 0 ] && cat && return
  [ "$#" -lt 2 ] && printf 'clize: falta regex para el color: %s\n' "$1" >&2 && return 1

  local color="$1"
  local regex="$2"
  shift 2

  if [ "$#" -eq 0 ]; then
    __clizepipe_one "$color" "$regex"
  else
    __clizepipe_one "$color" "$regex" | __clizepipe "$@"
  fi
}


__clize () {
  declare -a rules=()
  declare -a cmd=()
  declare found_separator=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --)
        found_separator=1
        shift
        cmd=("$@")
        break
        ;;
        
      -*)
        error "Parameter '$1' do not exist" exit 1
        ;;

      *)
        if [ "$#" -lt 3 ]; then
          error "Wrong syntax. Execute with '--help' to show usage info." exit 1
        fi

        rules+=("$1" "$2")
        shift 2
        ;;
    esac
  done

  if [ "$found_separator" -ne 1 ]; then
    error "clize: missing separator '--'" exit 1
  fi

  if [ "${#cmd[@]}" -eq 0 ]; then
    error "clize: missing command after --" exit 1
  fi

  script -qefc "$(printf '%q ' "${cmd[@]}")" /dev/null | __clizepipe "${rules[@]}"
}


#########################################################################################


printHelp () {
  echo "Usage: tcpdump2 [options ...] [expression]"
  echo
  echo "Colorized tcpdump for easy reading."
  echo
  echo "Options:"
  echo "  -h --help           Show this help message"
  echo "     --help-tcpdump   Show tcpdump help message."
  echo "  -V --version        Show version information"
  echo "  All other tcpdump options"
  echo
  echo "expression is a tcpdump filtering expression."
  echo
  echo "Colorized content are the following:"
  echo "  IP packets are marked in red, while IP6 packets in purple." | __clizepipe_one red "red|IP " | __clizepipe_one purple "purple|IP6"
  echo "  Protocols are marked in yellow: " | __clizepipe_one yellow 'yellow'
  echo "    BOOTP, DHCP, VRRPv2, VRRP, STP, ARP, TCP, UDP, and Flags []." | __clizepipe_one yellow 'BOOTP|DHCP|VRRPv2|VRRP|STP|ARP|TCP|UDP|Flags \[\]'
  echo "  IP addrs are marked in blue, but local addrs in green." | __clizepipe_one blue "blue|IP addrs" | __clizepipe_one green "green|local addrs"
}

printVersion () {
  echo "TCPDump2 v$VERSION ($RELEASE_DATE) - By $AUTHOR"
}



#Force to run under root
if [ $EUID -ne 0 ]; then
  echo "Requires root"
  
  #satrs=""
  satrs=()
  while [ $# -gt 0 ]; do
    #if [ $(echo "$1" | wc -w) -gt 1 ]; then
    #  satrs="${satrs:+"$satrs "}\"$1\""
    #else
    #  satrs="${satrs:+"$satrs "}$1"
    #fi
    satrs+=("$1")
    shift
  done
  #sudo ${0} ${satrs}
  sudo ${0} ${satrs[@]}
  exit $?
fi


checkDependencies


p_attrs=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      printHelp
      exit 0
      ;;
      
    -V|--version)
      printVersion
      exit 0
      ;;
      
    --help-tcpdump)
      tcpdump --help
      exit 0
      ;;

    *)
      p_attrs+=("$1")
      ;;
  esac
  shift
done



localips="$(ip -br a | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | tr ' ' '|')"

__clize red 'IP |>' purple 'IP6|ARP|STP 802\.1s' blue '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' green "$localips" yellow 'BOOTP|DHCP|VRRPv2|VRRP|TCP|UDP|Flags \[[.FPSR]+\]' -- tcpdump -n ${p_attrs[@]}

exit $?
