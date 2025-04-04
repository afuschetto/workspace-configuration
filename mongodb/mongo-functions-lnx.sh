################################################################################
### Global settings
################################################################################

MONGO_GIT_REMOTE=git@github.com:10gen/mongo.git
MONGO_VENV_DIR=${MONGO_VENV_DIR:-'.venv'}
MONGO_VENV_BIN=${MONGO_VENV_DIR}/bin
MONGO_ICECREAM_HOSTNAME=${MONGO_ICECREAM_HOSTNAME:-'iceccd-graviton.production.build.10gen.cc'}

################################################################################
### Build functions
################################################################################

# Resets the working tree to its initial state (as if it had just been cloned)
# and creates a Python virtual environment with all the requirements installed.
# All uncommitted changes and unversioned files will be lost (subject to
# confirmation by the user).
#
# Synopsis:
#   mongo-prepare [BRANCH] [OPTIONS]
#
# Options:
#   - Untracked files: --no-clean (default), --clean
mongo-prepare ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args $@;

	if [[ -z ${__echo} && ${__clean} == 1 ]]; then
		echo "WARNING: All uncommitted changes and unversioned files will be lost";
		read -p "Are you sure you want to proceed? [y/N] ";
		[[ ${REPLY} =~ (y|Y) ]] || return 0;
	fi

	[[ -n ${VIRTUAL_ENV} ]] && ${__echo} deactivate;
	if [[ ${__clean} == 1 ]]; then
		${__echo} \git clean -fdx --exclude=".vscode*";
		${__echo} \ccache -C;
	fi

	${__echo} \rm -rf ${MONGO_VENV_DIR} node_modules;
	${__echo} ${__toolchain_bin}/python3 -m venv ${MONGO_VENV_DIR};
	${__echo} . ${MONGO_VENV_BIN}/activate;
	${__echo} ${MONGO_VENV_BIN}/python3 -m pip install -U pip;

	case ${__branch} in
		v8.1 | master)
			${__echo} ${MONGO_VENV_BIN}/python3 -m pip install poetry==2.0.0;
			${__echo} export PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring;
			${__echo} ${MONGO_VENV_BIN}/python3 -m poetry install --no-root --sync
		;;
		v8.0)
			# Dirty fix (https://mongodb.slack.com/archives/CR8SNBY0N/p1743416688220929
			${__echo} ${MONGO_VENV_BIN}/python3 -m pip install zope-interface==5.0.0;
			${__echo} ${MONGO_VENV_BIN}/python3 -m pip install poetry==2.0.0;
			${__echo} export PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring;
			${__echo} ${MONGO_VENV_BIN}/python3 -m poetry install --no-root --sync
		;;
		v6.0)
			# Dirty fix (https://mongodb.slack.com/archives/CR8SNBY0N/p1738691783057339)
			${__echo} ${MONGO_VENV_BIN}/python3 -m pip install -U "setuptools<71.0.0"
			${__echo} ${MONGO_VENV_BIN}/python3 -m pip install -r etc/pip/dev-requirements.txt
		;;
		*)
			${__echo} ${MONGO_VENV_BIN}/python3 -m pip install -r etc/pip/dev-requirements.txt
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
# Synopsis:
#   mongo-configure [BRANCH] [OPTIONS]
#
# Options:
#   - Compiler family: --clang (default), --gcc
#   - Compiling mode: --debug (default), --release
#   - Linking mode: --dynamic (default), --static
#   - All those of buildscripts/scons.py
mongo-configure ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args $@;

	if [[ ${__support_bazel} == 1 ]]; then
		echo "ERROR: Bazel is not supported" 1>&2;
		return 1;
	fi

	__mongo-configure-ninja $@;
	__mongo-configure-compiledb $@ )
}

# Builds all the executables. If the `build.ninja` or `compile_commands.json`
# file is missing (e.g. at first run), it is automatically generated. Source
# files are also formatted before being compiled.
#
# Synopsis:
#   mongo-build [BRANCH] [OPTIONS]
#
# Options:
#   - Compiler family: --clang (default), --gcc
#   - Compiling mode: --debug (default), --release
#   - Linking mode: --dynamic (default), --static
#   - Executables to build: --all, --devcore (default), --core,
#   - Code formatting: --format (default), --no-format
#   - All those of ninja
mongo-build ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-check-venv;
	__mongo-parse-args $@;

	if [[ ${__support_bazel} == 1 ]]; then
		echo "ERROR: Bazel is not supported" 1>&2;
		return 1;
	fi

	[[ ${__format} == 1 ]] && ${__echo} mongo-format;

	[[ -f build.ninja ]] || __mongo-configure-ninja $@;
	[[ -f compile_commands.json ]] || __mongo-configure-compiledb $@;

	${__echo} ninja \
			-j400 \
			generated-sources \
			install-${__target} \
			${__args[@]} )
}

# Formats the source code according to the conversion adopted by all development
# teams.
#
# Synopsis:
#   mongo-format [OPTIONS]
#
# Options:
#   - All those of buildscripts/clang_format.py
mongo-format ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-check-venv;
	__mongo-parse-args $@;

	${__echo} ${MONGO_VENV_BIN}/python3 buildscripts/clang_format.py \
			format-my )
}

# Deletes all files generated by running `mongo-build` function (i.e.
# executables and object files). However, it does not delete the files
# corresponding to the build configuration (i.e. `build.ninja` and
# `compile_commands.json`).
#
# Synopsis:
#   mongo-clean [OPTIONS]
#
# Options:
#   - Compiler family: --clang (default), --gcc
#   - Executables to delete: --all (default), --core
#   - All those of buildscripts/scons.py
mongo-clean ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args $@;

	if [[ ${__support_bazel} == 1 ]]; then
		echo "ERROR: Bazel is not supported" 1>&2;
		return 1;
	fi

	${__echo} ninja -t clean;
	${__echo} ccache -C )
}

################################################################################
### Test functions
################################################################################

# Finds all the suites on which the passed JS test can run.
#
# Synopsis:
#   mongo-find-suites [BRANCH] [FILE]
mongo-find-suites ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-check-venv;
	__mongo-parse-args $@;

	case ${__branch} in
		v8.0 | v8.1 | master)
			${__echo} ${MONGO_VENV_BIN}/python3 build/install/bin/resmoke.py \
					find-suites \
					${__args[@]}
		;;
		*)
			${__echo} ${MONGO_VENV_BIN}/python3 buildscripts/resmoke.py \
					find-suites \
					${__args[@]}
		;;
	esac )
}

# Runs on the current machine the infrastructure to process the specified
# JavaScript test. This proposes the last commit comment as a description of the
# patch, however it also allows to provide a custom message.
#
# Synopsis:
#   mongo-test-locally [BRANCH] [OPTIONS] [FILE]
#
# Options:
#   - Concurrency: --single-task (default), --multi-task
#   - All those of build/install/bin/resmoke.py
mongo-test-locally ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-check-venv;
	__mongo-parse-args --master $@;

	${__echo} \rm -f executor.log fixture.log tests.log;
	set +e;
	case ${__branch} in
		v8.0 | v8.1 | master)
			${__echo} ${MONGO_VENV_BIN}/python3 build/install/bin/resmoke.py \
					run \
					--jobs=${__tasks} \
					--log=file \
					--storageEngine=wiredTiger \
					--storageEngineCacheSizeGB=0.5 \
					--mongodSetParameters='{logComponentVerbosity: {verbosity: 2}}' \
					--runAllFeatureFlagTests \
					${__args[@]}
		;;
		*)
			${__echo} ${MONGO_VENV_BIN}/python3 buildscripts/resmoke.py \
					run \
					--jobs=${__tasks} \
					--log=file \
					--storageEngine=wiredTiger \
					--storageEngineCacheSizeGB=0.5 \
					--mongodSetParameters='{logComponentVerbosity: {verbosity: 2}}' \
					--runAllFeatureFlagTests \
					${__args[@]}
		;;
	esac )
}

# Creates a new Evergreen path where it is possible to select the specific
# suites to run. By default, all required suites are pre-selected.
#
# Synopsis:
#   mongo-test-remotely [BRANCH] [OPTIONS]
#
# Options:
#   - All those of evergreen patch
mongo-test-remotely ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args $@;

	msg=$(git log -n 1 --pretty=%B | head -n 1);
	if [[ ${__echo} != echo ]]; then
		echo ${msg};
		read -p "Do you want change the title of this Evergreen patch? [y/N] ";
		if [[ ${REPLY} =~ (y|Y) ]]; then
			read -p "Type the custom title: " msg;
		fi;
	fi;

	${__echo} evergreen patch \
			--project mongodb-mongo-${__branch} \
			--skip_confirm \
			--description "[$(git rev-parse --abbrev-ref HEAD)] ${msg}" \
			${__args[@]} )
}

################################################################################
### Utility functions
################################################################################

# Clones the Git repository into the given directory (master as default).
#
# Synopsis:
#   mongo-clone [BRANCH] [OPTIONS] DIR
mongo-clone ()
{
	( set -e;
	__mongo-parse-args $@;

	if [[ ${#__args[@]} == 0 ]]; then
		echo "ERROR: Missing directory name for the local repository" 1>&2;
		return 1;
	fi
	${__echo} \git clone ${MONGO_GIT_REMOTE} \
			--branch ${__branch} \
			${__args[@]} )
}

# Synopsis:
#   mongo-merge [BRANCH] [OPTIONS]
mongo-merge ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args $@;

	${__echo} evergreen commit-queue merge \
			--project mongodb-mongo-${__branch} \
			${__args[@]} )
}

# Synopsis:
#   mongo-monitor-buildnodes [OPTIONS]
mongo-monitor-buildnodes ()
{
	( set -e;
	__mongo-parse-args $@;

	${__echo} icecream-sundae -s ${MONGO_ICECREAM_HOSTNAME} )
}

# Synopsis:
#   mongo-debug [OPTIONS]
mongo-debug ()
{
	( set -e;
	__mongo-parse-args $@;

	echo __echo=${__echo};
	echo __clean=${__clean};
	echo __branch=${__branch};
	echo __toolchain_bin=${__toolchain_bin};
	echo __support_bazel=${__support_bazel};
	echo __compiler=${__compiler};
	echo __build_mode=${__build_mode};
	echo __link_model=${__link_model};
	echo __format=${__format};
	echo __target=${__target};
	echo __tasks=${__tasks};
	echo __args=${__args} )
}

################################################################################
### Internal functions
################################################################################

__mongo-check-wrkdir ()
{
	if [[ ! -d buildscripts ]]; then
		echo "ERROR: ${PWD} is not a mongo working directory" 1>&2;
		return 1;
	fi
}

__mongo-check-venv ()
{
	if [[ -z ${VIRTUAL_ENV} ]]; then
		if [[ -d ./${MONGO_VENV_DIR} ]]; then
			echo "NOTE: Implicit activation of Python virtual environment";
			. ${MONGO_VENV_BIN}/activate;
		else
			echo "ERROR: No Python virtual environment to activate" 1>&2;
			return 1;
		fi
	fi
}

__mongo-parse-args ()
{
	__echo=;
	__clean=0;
	__branch=master;
	__toolchain_bin=/opt/mongodbtoolchain/v5/bin;
	__support_bazel=1;
	__compiler=clang;
	__build_mode='--opt=off --dbg=on';
	__link_model='--link-model=dynamic';
	__format=1;
	__target=devcore;
	__tasks=1;
	__args=();

	while [[ $# -gt 0 ]]; do
		case $1 in
			--echo)
				__echo=echo;
				shift
			;;
			--clean)
				__clean=1;
				shift
			;;
			--no-clean)
				__clean=0;
				shift
			;;
			--master)
				__branch=master;
				__toolchain_bin=/opt/mongodbtoolchain/v5/bin;
				__support_bazel=1;
				shift
			;;
			--v8.1)
				__branch=v8.1;
				__toolchain_bin=/opt/mongodbtoolchain/v4/bin;
				__support_bazel=1;
				shift
			;;
			--v8.0)
				__branch=v8.0;
				__toolchain_bin=/opt/mongodbtoolchain/v4/bin;
				__support_bazel=0;
				shift
			;;
			--v7.0)
				__branch=v7.0;
				__toolchain_bin=/opt/mongodbtoolchain/v4/bin;
				__support_bazel=0;
				shift
			;;
			--v6.0)
				__branch=v6.0;
				__toolchain_bin=/opt/mongodbtoolchain/v3/bin;
				__support_bazel=0;
				shift
			;;
			--clang)
				__compiler=clang;
				shift
			;;
			--gcc)
				__compiler=gcc;
				shift
			;;
			--debug)
				__build_mode='--opt=off --dbg=on';
				shift
			;;
			--release)
				__build_mode='--opt=on --dbg=off';
				shift
			;;
			--dynamic)
				__link_model='--link-model=dynamic';
				shift
			;;
			--static)
				__link_model='--link-model=static';
				shift
			;;
			--format)
				__format=1;
				shift
			;;
			--no-format)
				__format=0;
				shift
			;;
			--all)
				__target=all;
				shift
			;;
			--core)
				# Build mongos and mongod
				__target=core;
				shift
			;;
			--devcore)
				# Build mongos, mongod and jstestshell (for JS tests)
				__target=devcore;
				shift
			;;
			--mongod)
				__target=mongod;
				shift
			;;
			--mongos)
				__target=mongos;
				shift
			;;
			--mono-task)
				__tasks=1;
				shift
			;;
			--multi-task)
				__tasks=`cat /proc/cpuinfo | grep processor | wc -l`;
				shift
			;;
			*)
				__args+=($1);
				shift
			;;
		esac;
	done;
}

__mongo-configure-ninja ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-check-venv;
	__mongo-parse-args $@;

	${__echo} ${MONGO_VENV_BIN}/python3 buildscripts/scons.py \
			--variables-files=etc/scons/mongodbtoolchain_stable_${__compiler}.vars \
			${__build_mode} \
			${__link_model} \
			--ninja generate-ninja \
			ICECC=icecc \
			CCACHE=ccache \
			${__args[@]} )
}

__mongo-configure-compiledb ()
{
	( set -e;
	__mongo-check-wrkdir;
	__mongo-parse-args $@;

	${__echo} ninja \
			compiledb \
			${__args[@]} )
}
