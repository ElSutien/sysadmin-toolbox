#!/bin/bash


VERSION="1.2"
RELEASE_DATE="30/10/2026"
AUTHOR="ElSutien"


# Check needed dependencies for execution
checkDependencies () {
  local dependecies="grep script"
  local res=0 x
  for x in $dependencies; do
    which $x 1>/dev/null 2>&1 || error "Dependencies not met for '$x'" exit 5
  done
}

# Print an error message to stderr
# $1 : String to print
# stderr: Printed message
perror () {
  [ -t 2 ] && local CNC="\033[0m" CRED="\033[1;31m" || local CNC= CRED=
  echo -e "${CRED}ERROR: $*${CNC}" 1>&2
}

# Print an error message and perform an action
# $1 : String to print
# $* : Command to execute after print
error () {
  perror "${1}"
  shift
  [ $# -gt 0 ] && { eval $@; return $?; }
}

__clizepipe_one () {
  local red='1;31'
  local green='1;32'
  local yellow='1;33'
  local blue='1;34'
  local purple='1;35'
  local cyan='1;36'
  GREP_COLORS="ms=${!1}" grep --line-buffered --color=always -Ei "$|${2}"
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


printHelp () {
  echo "Usage: clize [options] [COLOR REGEX ...] -- COMMAND [ARGS ...]"
  echo
  echo "Colorize the output of a command using regex."
  echo
  echo "Options:"
  echo "  -h --help      Show this help message"
  echo "  -V --version   Show version information"
  echo
  echo "COLOR is a predefined color. Available are:"
  echo "  red    -- EXAMPLE" | __clizepipe_one red EXAMPLE
  echo "  green  -- EXAMPLE" | __clizepipe_one green EXAMPLE
  echo "  yellow -- EXAMPLE" | __clizepipe_one yellow EXAMPLE
  echo "  blue   -- EXAMPLE" | __clizepipe_one blue EXAMPLE
  echo "  purple -- EXAMPLE" | __clizepipe_one purple EXAMPLE
  echo "  cyan   -- EXAMPLE" | __clizepipe_one cyan EXAMPLE
  echo
  echo "REGEX is a regular expression with Grep Extended Syntax."
}

printVersion () {
  echo "Clize v$VERSION ($RELEASE_DATE) - By $AUTHOR"
}


checkDependencies

declare -a rules=()
declare -a cmd=()
declare found_separator=0

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
exit $?