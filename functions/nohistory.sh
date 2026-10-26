#!/bin/bash
(return 0 2>/dev/null) || { echo "This file can only be sourced"; exit 1; }


nohistory() {
  echo "Opened subshell with disabled bash history."
  bash --rcfile <(echo "source ~/.bashrc; unset HISTFILE; cd $PWD")
  echo "Returned to normal shell (with history)."
}