# Resets the working tree to its initial state (as if it had just been cloned)
# and creates a virtual Python environment with all the requirements installed.
# All uncommitted changes and unversioned files will be lost (subject to
# confirmation by the user).
#
# Options:
#   - Branch: --master (default), --v5.3, --v5.0, --v4.4, --v4.2, --v4.0
mongo-prepare ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args $@;

	if [[ ${__cmd_prefix} != echo ]]; then
		echo "WARNING: All uncommitted changes and unversioned files will be lost";
		read -p "Are you sure you want to proceed? [y/N] ";
		[[ ${REPLY} =~ (y|Y) ]] || return 0;
	fi

	[[ -n ${VIRTUAL_ENV} ]] && ${__cmd_prefix} deactivate;
	${__cmd_prefix} \git clean -fdx;
	${__cmd_prefix} ccache -C;

	case ${__mongo_branch} in
	v4.2 | v4.4 | v5.0 | v5.3 | master)
		${__cmd_prefix} \python3 -m venv .venv;
		${__cmd_prefix} . .venv/bin/activate;
		${__cmd_prefix} .venv/bin/python3 -m pip install -r buildscripts/requirements.txt --use-feature=2020-resolver
		;;
	v4.0)
		${__cmd_prefix} \virtualenv -p python2 .venv;
		${__cmd_prefix} . .venv/bin/activate;
		${__cmd_prefix} .venv/bin/python2 -m pip install -r buildscripts/requirements.txt --use-feature=2020-resolver
		;;
	*)
		echo "ERROR: ${__mongo_branch} branch is not supported by ${FUNCNAME[0]}" 1>&2;
		return 1
		;;
	esac )
}

# Generates the `build.ninja` and `compile_commands.json` files, which are
# required by the underlying build system (i.e. Ninja) and the language server
# (i.e. ccls or clangd) respectively. The `mongo-build` function automatically
# generates these files when they do not exist. However, this function must be
# explicitly executed when a SCons configuration is changed (e.g. after adding
# or removing a source file) and consequently the `build.ninja` and
# `compile_commands.json` files must be recreated.
#
# Options:
#   - Branch: --master (default), --v5.3, --v5.0, --v4.4, --v4.2, --v4.0
#   - Compiler family: --clang (default), --gcc
#   - Compiling mode: --debug (default), --release
#   - Linking mode: --dynamic (default), --static
#   - All those of buildscripts/scons.py
mongo-configure ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args $@;

	__mongo-configure-ninja $@;
	__mongo-configure-compilation-db $@ )
}

# Builds all the executables. If the `build.ninja` or `compile_commands.json`
# file is missing (e.g. at first run), it is automatically generated. Source
# files are also formatted before being compiled.
#
# Options:
#   - Branch: --master (default), --v5.3, --v5.0, --v4.4, --v4.2, --v4.0
#   - Compiler family: --clang (default), --gcc
#   - Compiling mode: --debug (default), --release
#   - Linking mode: --dynamic (default), --static
#   - Executables to build: --all (default), --core
#   - Code formatting: --format (default), --no-format
#   - All those of ninja
mongo-build ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args $@;

	[[ ${__format} == 1 ]] && ${__cmd_prefix} mongo-format ${__mongo_branch}

	case ${__mongo_branch} in
	v4.4 | v5.0 | v5.3 | master)
		[[ -f build.ninja ]] || __mongo-configure-ninja $@;
		[[ -f compile_commands.json ]] || __mongo-configure-compilation-db $@;
		${__cmd_prefix} ninja \
			-j400 \
			generated-sources \
			install-${__target} \
			${__args[@]}
		;;
	v4.0 | v4.2)
		[[ -f compile_commands.json ]] || __mongo-configure-compilation-db $@;
		${__cmd_prefix} ./buildscripts/scons.py \
			--variables-files=etc/scons/mongodbtoolchain_stable_${__toolchain}.vars \
			${__build_mode} \
			ICECC=icecc \
			generated-sources \
			${__target} \
			${__args[@]}
		;;
	*)
		echo "ERROR: ${__mongo_branch} branch is not supported by ${FUNCNAME[0]}" 1>&2;
		return 1
		;;
	esac )
}

# Deletes all files generated by running `mongo-build` function (i.e.
# executables and object files). However, it does not delete the files
# corresponding to the build configuration (i.e. `build.ninja` and
# `compile_commands.json`).
#
# Options:
#   - Branch: --master (default), --v5.3, --v5.0, --v4.4, --v4.2, --v4.0
#   - Compiler family: --clang (default), --gcc
#   - Executables to delete: --all (default), --core
#   - All those of buildscripts/scons.py
mongo-clean ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args $@;

	case ${__mongo_branch} in
	v4.4 | v5.0 | v5.3 | master)
		${__cmd_prefix} ninja -t clean;
		${__cmd_prefix} ccache -c
		;;
	v4.0 | v4.2)
		${__cmd_prefix} ./buildscripts/scons.py \
			--variables-files=etc/scons/mongodbtoolchain_stable_${__toolchain}.vars \
			--clean \
			${__target}
		;;
	*)
		echo "ERROR: ${__mongo_branch} branch is not supported by ${FUNCNAME[0]}" 1>&2;
		return 1
		;;
	esac )
}

# Formats the source code according to the conversion adopted by all development
# teams.
#
# Options:
#   - Branch: --master (default), --v5.3, --v5.0, --v4.4, --v4.2, --v4.0
#   - All those of buildscripts/clang_format.py
mongo-format ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args $@;

	case ${__mongo_branch} in
	v4.4 | v5.0 | v5.3 | master)
		${__cmd_prefix} ./buildscripts/clang_format.py format-my
		;;
	v4.0 | v4.2)
		${__cmd_prefix} ./buildscripts/clang_format.py format
		;;
	*)
		echo "ERROR: ${__mongo_branch} branch is not supported by ${FUNCNAME[0]}" 1>&2;
		return 1
		;;
	esac )
}

# Runs on the current machine the infrastructure to process the specified
# JavaScript test. This proposes the last commit comment as a description of the
# patch, however it also allows to provide a custom message.
#
# Options:
#   - Concurrency: --single-task (default), --multi-task
#   - All those of buildscripts/resmoke.py
mongo-test-locally ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args --master $@;

	${__cmd_prefix} \rm -f executor.log fixture.log tests.log;
	set +e;
	${__cmd_prefix} ./buildscripts/resmoke.py run \
		--storageEngine=wiredTiger \
		--storageEngineCacheSizeGB=0.5 \
		--mongodSetParameters='{logComponentVerbosity: {verbosity: 2}}' \
		--jobs=${__tasks} \
		--log=file \
		${__args[@]} )
	#[[ $? == 0 ]] && echo -e '>> \e[0;32mPASSED\e[0m <<' || echo -e '>> \e[0;31mFAILED\e[0m <<' )
}

# Creates a new Evergreen path where it is possible to select the specific
# suites to run. By default, all required suites are pre-selected.
#
# Options:
#   - All those of evergreen patch
mongo-test-remotely ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args $@;

	msg=$(git log -n 1 --pretty=%B | head -n 1)
	if [[ ${__cmd_prefix} != echo ]]; then
		echo ${msg}
		read -p "Do you want to use this title for the Evergreen patch? [Y/n] ";
		if [[ ${REPLY} =~ (n|N) ]]; then
			read -p "Type the custom title: " msg
		fi
	fi

	${__cmd_prefix} evergreen patch \
		--project mongodb-mongo-${__mongo_branch} \
		--skip_confirm \
		--description "$(git branch --show-current) ${msg}" \
		${__args[@]} )
}

################################################################################

mongo-verify-tee ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args --master $@;

	${__cmd_prefix} \rm -f executor.log fixture.log tests.log;
	${__cmd_prefix} ./buildscripts/resmoke.py run \
		--storageEngine=wiredTiger \
		--storageEngineCacheSizeGB=0.5 \
		--mongodSetParameters='{logComponentVerbosity: {verbosity: 2}}' \
		--jobs=${__tasks} \
		${__args[@]} \
		| tee tests.log )
}

mongo-merge ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args $@;

	${__cmd_prefix} evergreen commit-queue merge \
		--project mongodb-mongo-${__mongo_branch} \
		${__args[@]} )
}

mongo-debug ()
{
	( set -e;
	__mongo-parse-args $@;

	echo __cmd_prefix=${__cmd_prefix}
	echo __mongo_branch=${__mongo_branch}
	echo __toolchain=${__toolchain}
	echo __build_mode=${__build_mode}
	echo __link_model=${__link_model}
	echo __format=${__format}
	echo __target=${__target}
	echo __tasks=${__tasks}
	echo __args=${__args} )
}

################################################################################

###
### Internal
###

__mongo-check-wrkdir ()
{
	if [[ ! -d buildscripts ]]; then
		echo "ERROR: ${PWD} is not a mongo working directory" 1>&2;
		return 1;
	fi
}

__mongo-parse-args ()
{
	[[ -z ${__parsed_args} ]] && __parsed_args=true || return 0;

	__cmd_prefix=
	__mongo_branch=master
	__toolchain=clang
	__build_mode='--opt=off --dbg=on'
	__link_model='--link-model=dynamic'
	__format=1
	__target=all
	__tasks=1
	__args=()

	while [[ $# -gt 0 ]]; do
	case $1 in
		--echo)
			__cmd_prefix=echo;
			shift
			;;
		--master)
			__mongo_branch=master;
			shift
			;;
		--v5.3)
			__mongo_branch=v5.3;
			shift
			;;
		--v5.0)
			__mongo_branch=v5.0;
			shift
			;;
		--v4.4)
			__mongo_branch=v4.4;
			shift
			;;
		--v4.2)
			__mongo_branch=v4.2;
			shift
			;;
		--v4.0)
			__mongo_branch=v4.0;
			shift
			;;
		--clang)
			__toolchain=clang;
			shift
			;;
		--gcc)
			__toolchain=gcc;
			shift
			;;
		--debug)
			__build_mode='--opt=off --dbg=on'
			shift
			;;
		--release)
			__build_mode='--opt=on --dbg=off'
			shift
			;;
		--dynamic)
			__link_model='--link-model=dynamic'
			shift
			;;
		--static)
			__link_model='--link-model=static'
			shift
			;;
		--format)
			__format=1
			shift
			;;
		--no-format)
			__format=0
			shift
			;;
		--all)
			__target=all;
			shift
			;;
		--core)
			__target=core;
			shift
			;;
		--mono-task)
			__tasks=1
			shift
			;;
		--multi-task)
			__tasks=`cat /proc/cpuinfo | grep processor | wc -l`
			shift
			;;
		*)
			#if [[ $1 == -* ]]; then
			#	echo "ERROR: $1 is not a supported option" 1>&2;
			#	return 1;
			#fi
			__args+=($1)
			shift
			;;
	esac;
	done;

	#if [[ ${__mongo_branch} != master && ${__mongo_branch} != v5.0 && ${__mongo_branch} != v4.4 && ${__mongo_branch} != v4.2 && ${__mongo_branch} != v4.0 ]]; then
	#	echo "WARNING: ${__mongo_branch} is not a Git origin branch" 1>&2;
	#	read -p "Do you want to use the master branch as a reference? [y/N] ";
	#	[[ ${REPLY} =~ (y|Y) ]] && __mongo_branch=master || return 2;
	#fi
}

__mongo-configure-ninja ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args $@;

	case ${__mongo_branch} in
	master)
		${__cmd_prefix} ./buildscripts/scons.py \
			--variables-files=etc/scons/mongodbtoolchain_stable_${__toolchain}.vars \
			${__build_mode} \
			${__link_model} \
			--ninja generate-ninja \
			ICECC=icecc \
			CCACHE=ccache \
			${__args[@]}
		;;
	v4.4 | v5.0 | v5.3)
		${__cmd_prefix} ./buildscripts/scons.py \
			--variables-files=etc/scons/mongodbtoolchain_stable_${__toolchain}.vars \
			${__build_mode} \
			${__link_model} \
			--ninja generate-ninja \
			ICECC=icecc \
			CCACHE=ccache \
			${__args[@]}
		;;
	#*)
	#	echo "ERROR: ${__mongo_branch} branch is not supported by ${FUNCNAME[0]}" 1>&2;
	#	return 1
	#	;;
	esac )
}

__mongo-configure-compilation-db ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args $@;

	case ${__mongo_branch} in
	v4.4 | v5.0 | v5.3 | master)
		${__cmd_prefix} ninja \
			compiledb \
			${__args[@]}
		;;
	v4.0 | v4.2)
		${__cmd_prefix} ./buildscripts/scons.py \
			--variables-files=etc/scons/mongodbtoolchain_stable_${__toolchain}.vars \
			${__build_mode} \
			ICECC=icecc \
			compiledb \
			${__args[@]}
		;;
	*)
		echo "ERROR: ${__mongo_branch} branch is not supported by ${FUNCNAME[0]}" 1>&2;
		return 1
		;;
	esac )
}
