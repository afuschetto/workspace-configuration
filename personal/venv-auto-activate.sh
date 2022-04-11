#!/bin/bash

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
