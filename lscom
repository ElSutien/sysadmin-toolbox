#!/bin/bash

NAME="lsCom"
AUTHOR="ElSutien"
VERSION=1.0
RELEASE_DATE="18/12/2025"


# FUNCTION print help message
print_help() {
  echo "${NAME} v${VERSION} - By ${AUTHOR}"
  echo "Get COM ports connected to the system"
  echo
  echo "Usage: lscom [options] [device]"
  echo
  echo "  device    Is a device name to search for instead"
  echo "            of listing all."
  echo
  echo "  Options:"
  echo "    -h  --help     Invoke this help message."
  echo "    -V  --version  Invoke version info message."
}

# FUNCTION print version message
print_version() {
  echo "${NAME} - By ${AUTHOR}"
  echo "Version ${VERSION} from ${RELEASE_DATE}"
}

# Print an error message to stderr
# $1 : String to print
# stderr: Printed message
perror() {
  echo "ERROR: $*" 1>&2
}


# FUNCTION get all TTY USB devices names
# stdout : list of device names
# return: 0 if exist; 1 if not
function getTtyUsbDevs () {
  echo "$(ls -1 /sys/class/tty/ | grep ttyUSB )"
  return $?
}

# FUNCTION get all TTY ACM devices names
# stdout : list of device names
# return: 0 if exist; 1 if not
function getTtyAcmDevs () {
  echo "$(ls -1 /sys/class/tty/ | grep ttyACM )"
  return $?
}


# FUNCTION get usb bus line for a given device
# $1 : str name of the tty device
# stdout : usb bus line for the device
# return: 0 on success; 1 on fail
function getBusDevTty () {
  # Exit when no device specified
  [ -z "${1}" ] && return 1
  # Get full udev info
  local rawinfo=$(udevadm info --name=/dev/${1} --attribute-walk)
  # Retrieve BUS id
  local bus=$(echo "$rawinfo" | sed -n 's/\s*ATTRS{busnum}==\"\([^\"]\+\)\"/\1/p' | head -n 1 | awk '{printf("%03d\n", $1)}')
  # Retrieve DEV id
  local dev=$(echo "$rawinfo" | sed -n 's/\s*ATTRS{devnum}==\"\([^\"]\+\)\"/\1/p' | head -n 1 | awk '{printf("%03d\n", $1)}')
  
  # If usb device do not exist, exit
  [ -e /dev/bus/usb/${bus}/${dev} ] || return 1
  
  # Else, get the usb device line and print it
  local usbline=$(lsusb -s ${bus}:${dev})
  echo "$usbline"
  return 0
}



# MAIN FUNCTION
function main () {
  local p_dev
  
  #Process input parameters
  while [ $# -gt 0 ]; do
    case $1 in
      -h|--help)
        print_help
        exit 0
        ;;
      
      -V|--version)
        print_version
        exit 0
        ;;
        
      -*)
        perror "Parameter '$1' do not exist"
        exit 10
        ;;
  
      *)
        if [ -z "$p_dev" ]; then
          p_dev="${1}"
        else
          perror "Multiple devices specified"
          exit 1
        fi
        ;;
    esac
    shift #Pass processed parameter
  done

  local devsL

  if [ -n "$p_dev" ]; then
    if ls -1 /sys/class/tty/${p_dev} 1>/dev/null 2>&1; then
      devsL="${p_dev}"
    else
      perror "Specified device do not exist"
      exit 2
    fi
  else
    # Retrieve all external TTY devices
    devsL=$(getTtyUsbDevs)
    devsL+="${devsL:+ }"
    devsL+=$(getTtyAcmDevs)
  fi
  
  # For each device, fetch its bus line
  for x in ${devsL}; do
    if getBusDevTty ${x}; then
      echo " + /dev/${x}"
    fi
  done
}


# Execute main function
main $*