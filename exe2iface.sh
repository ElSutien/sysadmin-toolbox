#!/bin/bash

NAME="exe2iface"
VERSION="0.4"
RELEASE_DATE="30/10/2026"
AUTHOR="ElSutien"


# FUNCTION Print an error message to stderr with color
# Parameters:
#   - 1*: str Message to print
# Stderr: Printed message with colors
# Date: 30/10/20226
perror () {
  [ -t 2 ] && local CNC="\033[0m" CRED="\033[1;31m" || local CNC= CRED=
  echo -e "${CRED}ERROR: ${@}${CNC}" 1>&2
}

# FUNCTION Print an info message to stdout with color
# Parameters:
#   - 1*: str Message to print
# Stdout: Printed message with colors
# Date: 30/10/20226
pinfo () {
  [ -t 1 ] && local CNC="\033[0m" CBLU="\033[1;36m" || local CNC= CRED=
  echo -e "${CBLU}INFO: ${@}${CNC}"
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





# FUNCTION for ask an option of Yes or No
# Parameters:
#   - 1 : str of the question to ask the user
#   - 2 : varname of the variable to store the result [optional]
#   - 3 : char of the default value ('y' or 'n') [optional]
# Returns: 0 for yes, 1 for no 
#          byRef: 'y' for yes; 'n' for no
# Date: 04/11/2026
askYesNo() {
    local opts
    local flag=0
    local inp
    local nl=$'\n'
    
    case $3 in
      y)
        opts="[Y/n]"
        ;;
      n)
        opts="[y/N]"
        ;;
      *)
        opts="[y/n]"
        ;;
    esac
    
    echo -n "${1} ${opts} "
    while [ $flag -eq 0 ]; do
      read -s -N 1 inp
      case "$inp" in
        [yY]|[nN])
          inp=$(echo "$inp" | awk '{print tolower($0)}')
          flag=1
          ;;
        $'\n')
          if [ -n "$3" ]; then
            flag=1
            inp=$(echo "$3" | awk '{print tolower($0)}')
          fi
          ;;
      esac
    done
    echo -n "$inp"
    echo
    
    if [ "$inp" == "y" ]; then
      [ -n "$2" ] && eval $2=y
      return 0
    else
      [ -n "$2" ] && eval $2=n
      return 1
    fi
}


# FUNCTION Check if Dev exist on system
# $1 : Dev name
checkDev () {
  ip link show dev ${1} 2>&1 1>/dev/null || return 1
  return 0
}

# FUNCTION Check if Dev used DHCP to configure
# $1 : Dev name
checkDevIsDhcp () {
  ip route show dev ${1} 2>&1 | grep default | grep -q "proto dhcp" || return 1
  return 0
}

# FUNCTION Check if a NetNS exist on system
# Parameters:
#   - 1 : str Name of the netns
# Returns: 0 for yes; 1 for no
checkNetns () {
  ip netns | grep -xq "${1}" || return 1
  return 0
}

# FUNCTION Get default route for Dev
# $1 : Dev name
getDefRouteDev () {
  ip route show dev ${1} 2>&1 1>/dev/null || return 1
  local route=$(ip route show dev ${1} 2>&1 | grep default | awk '{print $3}')
  [ -n "$route" ] && echo "$route" || return 2
  return 0
}

# FUNCTION Get IPs of an iface
# $1 : iface name
# Stdout : vector of IPs for the iface
getIpDev () {
  (set -- $(ip -br -4 a sh dev $1) && shift 2 && echo "$*")
  return $?
}

# FUNCTION Cleanup all network changes done by the program
cleanup () {
  pinfo "Cleaning up system network..."
  #Check if the netns is up
  if [ -n "${NETNS}" ]; then
    if checkNetns "${NETNS}"; then
      ip netns delete ${NETNS} || perror "Namespace could not be deleted"
    fi
  fi
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



p_iface=
p_cmd=()
p_iswlan=0

while [ $# -gt 0 ]; do
	case $1 in
		--help|-h)
		  echo "$NAME. Version $VERSION - By ElSutien"
		  echo "Release date: $RELEASE_DATE"
		  echo ""
		  echo "Utility to run a command and childs under a specific network interface."
		  echo ""
		  echo "HELP: $NAME [options] <Iface> [command [attrs ...]]"
		  echo ""
		  echo "      Options:"
		  echo "        -w --wlan     Interface is a Phy-Wlan iface"
		  echo "        -h --help     Show this help"
		  echo "        -V --version  Show version information"
		  echo ""
		  echo "      Default command: bash"
		  exit 0
		  ;;
		  
		--version|-V)
		  echo "$NAME $VERSION - By $AUTHOR"
		  exit 0
		  ;;
		  
		-w|--wlan)
			p_iswlan=1
			;;
		  
		-*)
		  error "Option $1 do not exist."
		  exit 1
		  ;;
		  
		*)
		  if [ -z "$p_iface" ]; then
		    p_iface="$1"
		  else
		    p_cmd+=("$1")
		  fi
		  ;;
	esac
	shift
done


#Evaluate prerequisites
[ -n "$p_iface" ] && IFACE="$p_iface" || error "Parameter Iface not given" exit 1

#Set the default command to bash
[ -z "${p_cmd[@]}" ] && p_cmd+=("bash")



#Checking interface
checkDev $IFACE || error "Iface '$IFACE' do not exist" exit 2
checkDevIsDhcp $IFACE && isDhcp=1 || isDhcp=0

# Get interface values when no DHCP
if [ $isDhcp -eq 0 ]; then
  ifroute=$(getDefRouteDev $IFACE)
  ifip=$(getIpDev $IFACE)
else
  pinfo "Interface will be configured using DHCP"
fi


#Create a trap to cleanup
trap 'cleanup' EXIT SIGTERM SIGINT SIGKILL

#Set variables
NETNS="ns_${IFACE}_${$}"



pinfo "Creating namespace..."
[ $(ip netns | grep "$NETNS" | wc -l) -eq 1 ] && error "Creating net namespace. Already exist" exit 3
ip netns add ${NETNS} || error "Creating net namespace. Kernel error" exit 3

if [ $p_iswlan -eq 0 ]; then
  pinfo "Linking net device..."
  ip link set ${IFACE} netns ${NETNS} || error "Linking net iface. Can not link to NS" exit 4
else
  PHY=$(iw dev | grep -E "${IFACE}|^phy" | grep -B1 "${IFACE}" | head -n1 | sed 's/#//')
  #NETNSPID=$(ip netns exec ${NETNS} bash -c 'sleep 1 >&- & echo "$!"')
  pinfo "Moving physical device $PHY to namespace..."
  iw phy ${PHY} set netns name ${NETNS} || error "Linking phy device. Can not link PHY to NS" exit 4
fi

ip -n ${NETNS} link set ${IFACE} up || error "Linking net iface. Can not bring iface up" exit 4

# If found static config, ask to configure
if [ $isDhcp -eq 0 ] && [ -n "$ifroute" ] && [ -n "$ifip" ]; then
  echo "Found static config:"
  echo "  IP: $ifip"
  echo "  Gateway: $ifroute"
  if askYesNo "Do you want to configure?" "" y; then
    for x in $ifip; do
      ip -n ${NETNS} address add $x dev ${IFACE}
    done
    ip -n ${NETNS} route add default via $ifroute dev ${IFACE}
  fi
fi

if [ $p_iswlan -eq 0 ]; then
  if askYesNo "Do you want to enable DHCP?" "" y; then
    pinfo "Getting DHCP..."
    ip netns exec ${NETNS} dhcpcd ${IFACE} 1>/dev/null 2>&1 || error "Getting DHCP" exit 5
  fi
else
  if [ -x /usr/libexec/iwd ]; then
    echo "IWd detected on system"
    if askYesNo "Do you want to enable IWd daemon?" "" y; then
      pinfo "Starting iwd on background..."
      ip netns exec ${NETNS} /usr/libexec/iwd 1>/dev/null 2>&1 &
      daemonpid=$!
    fi
  fi
fi

pinfo "Executing command: ${p_cmd[@]}"
eval ip netns exec ${NETNS} ${p_cmd[@]} || error "Executing command"

if [ -n "$daemonpid" ]; then #If exist a background daemon
  kill $daemonpid
fi


#Disable cleanup trap
trap - EXIT SIGTERM SIGINT SIGKILL

#Restoring interface
if [ $p_iswlan -eq 0 ]; then
  pinfo "Disabling namespace..."
  ip -n ${NETNS} link set netns 1 dev ${IFACE} && ip link set ${IFACE} up || error "Recovering iface to root namespace"
else
  pinfo "Restoring phy device..."
  ip netns exec ${NETNS} iw phy ${PHY} set netns 1 || error "Recovering phy dev to root namespace"
  ip link set ${IFACE} up || error "Recovering iface"
fi

ip netns delete ${NETNS} || error "Deleting namespace"


if [ $p_iswlan -eq 1 ]; then #Check recovery for wlan ifaces
  sleep 1
  if ! checkDev ${IFACE}; then
    error "Iface ${IFACE} not well recovered"
    pinfo "Recreating iface..."
    iw phy ${PHY} interface add ${IFACE} type managed && pinfo "Iface ${IFACE} recovered!" || error "Iface ${IFACE} could not be created from ${PHY}"
  fi
fi