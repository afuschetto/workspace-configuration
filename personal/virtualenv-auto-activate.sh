#!/bin/bash
# virtualenv-auto-activate.sh
#
# Installation:
#   Add this line to your .bashrc or .bash-profile:
#
#       source /path/to/virtualenv-auto-activate.sh
#
#   Go to your project folder, run "virtualenv .venv", so your project folder
#   has a .venv folder at the top level, next to your version control directory.
#
#   The virtualenv will be activated automatically when you enter the directory.

#_virtualenv_auto_activate() {
#  if [ -e ".venv" ]; then
#    # Check to see if already activated to avoid redundant activating
#    if [ "$VIRTUAL_ENV" != "$(pwd -P)/.venv" ]; then
#      _VENV_NAME=$(basename `pwd`)
#      echo Activating virtualenv \"$_VENV_NAME\"...
#      VIRTUAL_ENV_DISABLE_PROMPT=1
#      . .venv/bin/activate
#      _OLD_VIRTUAL_PS1="$PS1"
#      #PS1="\[\e[0;36m\]($_VENV_NAME)$PS1"
#      PS1=$PS1
#      export PS1
#    fi
#  fi
#}

#export PROMPT_COMMAND=_virtualenv_auto_activate

cd ()
{
    builtin cd $@

    # Check there is no virtual environment activated.
    if [[ -z ${VIRTUAL_ENV} ]]; then
	# If the .venv directory is found then activate the virtual
	# environment.
	if [[ -d ./.venv ]]; then
	    . .venv/bin/activate
	fi
    else
	# If the current directory does not belong to earlier VIRTUAL_ENV
	# directory then deactivate the virtual environment.
	PARENT_DIR=$(dirname ${VIRTUAL_ENV})
	if [[ ${PWD}/ != ${PARENT_DIR}/* ]]; then
	    deactivate
	fi
    fi
}
