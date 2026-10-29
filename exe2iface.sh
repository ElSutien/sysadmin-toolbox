#!/bin/bash

NAME="exe2iface"
VERSION="0.3"
RELEASE_DATE="29/10/2026"
AUTHOR="ElSutien"

error () {
  echo -e "\033[1;31mERROR: ${1}\033[0m" 1>&2
  shift
  if [ $# -gt 0 ]; then
    eval $*
    return $?
  fi
}

info () {
  echo -e "\033[1;36mINFO: ${1}\033[0m"
}



# FUNCTION for ask an option of Yes or No
# Parameters:
#       - 1: str of the question to ask the user
#       - 2: name of the variable to store the result [optional]
#       - 3: char of the default value ('y' or 'n') [optional]
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

# FUNCTION Get the default route via for an iface
# $1 : Dev name
# $2 : var name to store Default Via IP
getDefaultViaDev () {
  local via=$(ip r show dev ${1} 2>&1 | grep default | awk '{print $3}')
  eval $2="\"$via\""
}


# $1 : destination IP
# $2 : Via IP
# $3 : Dev name
checkRule () {
  ip route show dev ${3} 2>&1 | grep -q "${1} via ${2} dev ${3}" && return 0 || return 1
}


# $1 : host
# echoes IP
resolveHost () {
  local addr
  if echo "$1" | grep -q "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"; then
    echo "$1"
  else
    addr=$(host -t A ${1} | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+") || return 1
    echo $addr
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
  info "Interface will be configured using DHCP"
fi


#Set variables
NETNS="ns_${IFACE}_${$}"



info "Creating namespace..."
[ $(ip netns | grep "$NETNS" | wc -l) -eq 1 ] && error "Creating net namespace. Already exist" exit 3
ip netns add ${NETNS} || error "Creating net namespace. Kernel error" exit 3

if [ $p_iswlan -eq 0 ]; then
  info "Linking net device..."
  ip link set ${IFACE} netns ${NETNS} || error "Linking net iface. Can not link to NS" exit 4
else
  PHY=$(iw dev | grep -E "${IFACE}|^phy" | grep -B1 "${IFACE}" | head -n1 | sed 's/#//')
  #NETNSPID=$(ip netns exec ${NETNS} bash -c 'sleep 1 >&- & echo "$!"')
  info "Moving physical device $PHY to namespace..."
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
    info "Getting DHCP..."
    ip netns exec ${NETNS} dhcpcd ${IFACE} 1>/dev/null 2>&1 || error "Getting DHCP" exit 5
  fi
else
  if [ -x /usr/libexec/iwd ]; then
    echo "IWd detected on system"
    if askYesNo "Do you want to enable IWd daemon?" "" y; then
      info "Starting iwd on background..."
      ip netns exec ${NETNS} /usr/libexec/iwd 1>/dev/null 2>&1 &
      daemonpid=$!
    fi
  fi
fi

info "Executing command: ${p_cmd[@]}"
eval ip netns exec ${NETNS} ${p_cmd[@]} || error "Executing command"

if [ -n "$daemonpid" ]; then #If exist a background daemon
  kill $daemonpid
fi

#Restoring interface
if [ $p_iswlan -eq 0 ]; then
  info "Disabling namespace..."
  ip -n ${NETNS} link set netns 1 dev ${IFACE} && ip link set ${IFACE} up || error "Recovering iface to root namespace"
else
  info "Restoring phy device..."
  ip netns exec ${NETNS} iw phy ${PHY} set netns 1 || error "Recovering phy dev to root namespace"
  ip link set ${IFACE} up || error "Recovering iface"
fi

ip netns delete ${NETNS} || error "Deleting namespace"