#!/bin/bash

VERSION="0.1"
RELEASE_DATE="22/09/2026"
AUTHOR="ElSutien"

localips="$(ip -br a | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | tr ' ' '|')"

clize red 'IP |>' purple 'IP6' blue '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' green "$localips" yellow 'VRRPv2|VRRP|STP|ARP|TCP|UDP|Flags \[[.FPSR]+\]' -- tcpdump -tn $*

#clize green "$(tr '\n' '|'<<<"$localips")" yellow 'VRRPv2|STP|UDP|Flags \[[.FPSR]+\]' -- tcpdump -tn $*
exit $?
