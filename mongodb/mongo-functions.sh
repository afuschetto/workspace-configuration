###
### Repository
###

# Reset the working directory to its initial state, as if the repository had
# just been cloned and its Python virtual environment created and properly
# initialized.
#
# Options:
#   --master, --v5.0, --v4.4, --v4.2, --v4.0
mongo-prepare ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args $@;

    echo "WARNING: All uncommitted changes and unversioned files will be lost";
    read -p "Are you sure you want to proceed? [y/N] ";
    [[ ${REPLY} =~ (y|Y) ]] || return 0;

    [[ -n ${VIRTUAL_ENV} ]] && deactivate;
    \git clean -fdx;
    ccache -C;

    case ${__mongo_branch} in
        v4.2 | v4.4 | v5.0 | master)
            \python3 -m venv .venv;
            .venv/bin/python3 -m pip install -r buildscripts/requirements.txt --use-feature=2020-resolver
            ;;
        v4.0)
            \virtualenv -p python2 .venv;
            .venv/bin/python2 -m pip install -r buildscripts/requirements.txt --use-feature=2020-resolver
            ;;
        *)
            echo "ERROR: ${__mongo_branch} branch is not supported by ${FUNCNAME[0]}" 1>&2;
            return 1
            ;;
    esac )
}

###
### Build
###

# Generate the "build.ninja" configuration file, which is required by the Ninja
# build system. This command is automatically run by "mongo-build" when the
# "build.ninja" file does not exist. However, the command must be explicitly
# invoked when a SCons configuration file is modified (e.g., after adding or
# removing a source file) and any existing "build.ninja" file must be updated.
#
# Options:
#   --master, --v5.0, --v4.4, --v4.2, --v4.0
#   --clang, --gcc
__mongo-configure-ninja ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args $@;

    case ${__mongo_branch} in
        v4.4 | v5.0 | master)
            ./buildscripts/scons.py \
                --variables-files=etc/scons/mongodbtoolchain_stable_${__toolchain}.vars \
                --opt=off \
                --dbg=on \
                --link-model=dynamic \
                --ninja generate-ninja \
                ICECC=icecc \
                CCACHE=ccache \
                ${__args[@]}
            ;;
        *)
            echo "ERROR: ${__mongo_branch} branch is not supported by ${FUNCNAME[0]}" 1>&2;
            return 1
            ;;
    esac )
}

# Generate the "compile_commands.json" file, which is required by the "ccls"
# tool (a C/C++ language server). The code editor (via a plugin) uses this file
# to run "ccls" in the background, indexing the source code and responding to
# requests from the editors. This command is automatically run by "mongo-build"
# when the "compile_commands.json" file does not exist. However, the command
# must be explicitly invoked when a SCons configuration file is modified (e.g.,
# after adding or removing a source file) and any exisiting "build.ninja" file
# must be updated.
#
# Options:
#   --master, --v5.0, --v4.4, --v4.2, --v4.0
#   --clang, --gcc
__mongo-configure-ccls ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args $@;

    case ${__mongo_branch} in
        v4.4 | v5.0 | master)
            ninja \
                compiledb generated-sources \
                ${__args[@]}
            ;;
        v4.2 | v4.0)
            ./buildscripts/scons.py \
                --variables-files=etc/scons/mongodbtoolchain_stable_${__toolchain}.vars \
                --opt=off \
                --dbg=on \
                ICECC=icecc \
                compiledb generated-sources \
                ${__args[@]}
            ;;
        *)
            echo "ERROR: ${__mongo_branch} branch is not supported by ${FUNCNAME[0]}" 1>&2;
            return 1
            ;;
    esac )
}

# Generate the "build.ninja" and "compile_commands.json" files, which are
# respectively required by the Ninja build system and the "ccls" tool (a C/C++
# language server). The "mongo-build" command generates these files when they do
# not exist. However, this command must be explicitly invoked when a SCons
# configuration is modified (e.g., after adding or removing a source file), and
# any existing "build.ninja" and "compile_commands.json" files must be updated.
#
# Options:
#   --master, --v5.0, --v4.4, --v4.2, --v4.0
#   --clang, --gcc
mongo-configure ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args $@;

    __mongo-configure-ninja $@;
    __mongo-configure-ccls $@ )
}

# Build the mongo project by adopting the build system supported by the origin
# branch and taking care of generating the "build.ninja" file when it is missing
# (by running the "mongo-configure" command).
#
# Options:
#   --master, --v5.0, --v4.4, --v4.2, --v4.0
#   --clang, --gcc
#   --all, --core
mongo-build ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args $@;

    case ${__mongo_branch} in
        v4.4 | v5.0 | master)
            [[ -f build.ninja ]] || __mongo-configure-ninja $@;
            [[ -f compile_commands.json ]] || __mongo-configure-ccls $@;
            ninja \
                -j400 \
                install-${__target} \
                ${__args[@]}
            ;;
        v4.2 | v4.0)
            [[ -f compile_commands.json ]] || __mongo-configure-ccls $@;
            ./buildscripts/scons.py \
                --variables-files=etc/scons/mongodbtoolchain_stable_${__toolchain}.vars \
                --opt=off \
                --dbg=on \
                ICECC=icecc \
                ${__target} \
                ${__args[@]}
            ;;
        *)
            echo "ERROR: ${__mongo_branch} branch is not supported by ${FUNCNAME[0]}" 1>&2;
            return 1
            ;;
    esac )
}

# Delete all files that are generated by the "mongo-build" command (i.e., object
# and target files). However, do not delete files that record the build
# configuration (e.g., "build.ninja").
#
# Options:
#   --master, --v5.0, --v4.4, --v4.2, --v4.0
#   --clang, --gcc
#   --all, --core
mongo-clean ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args $@;

    case ${__mongo_branch} in
        v4.4 | v5.0 | master)
            ninja -t clean;
            ccache -c
            ;;
        v4.2 | v4.0)
            ./buildscripts/scons.py \
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

# Format the source code according to the company-wide clang-format
# configuration.
#
# Options:
#   --master, --v5.0, --v4.4, --v4.2, --v4.0
mongo-format ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args $@;

    case ${__mongo_branch} in
        v4.4 | v5.0 | master)
            ./buildscripts/clang_format.py format-my
            ;;
        v4.2 | v4.0)
            ./buildscripts/clang_format.py format
            ;;
        *)
            echo "ERROR: ${__mongo_branch} branch is not supported by ${FUNCNAME[0]}" 1>&2;
            return 1
            ;;
    esac )
}

################################################################################

###
### Local tests
###

# Options:
#   --multi-task, --single-task
mongo-verify ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args --master $@;

    \rm -f executor.log fixture.log tests.log
    ./buildscripts/resmoke.py run \
	--storageEngine=wiredTiger \
        --storageEngineCacheSizeGB=0.5 \
        --mongodSetParameters='{logComponentVerbosity: {verbosity: 2}}' \
        --log=file \
        --jobs=${__tasks} \
        ${__args[@]} )
}

###
### Remote tests
###

mongo-send-evergreenpatch ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args $@;

    evergreen patch \
        --project mongodb-mongo-${__mongo_branch} \
        --description "$(git log -n 1 --pretty=%B | head -n 1)" \
        ${__args[@]} )
}

###
### Code review
###

mongo-send-codereview ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args $@;

    .venv/bin/python3 ${HOME}/support/kernel-tools/codereview/upload.py \
        --rev HEAD^:HEAD \
        --git_similarity=100 \
        --check-clang-format \
        --check-eslint \
        --title "$(git log -n 1 --pretty=%B | head -n 1)" \
        --cc "codereview-mongo@10gen.com,serverteam-sharding-emea@mongodb.com" \
        --jira_user "antonio.fuschetto" \
        ${__args[@]} )
}

###
### Merge
###

mongo-merge ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args $@;

    evergreen commit-queue merge \
        --project mongodb-mongo-${__mongo_branch} \
        ${__args[@]} )
}

################################################################################

###
### Utilities
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

    __args=()
    __mongo_branch=master
    __toolchain=clang
    __target=all
    __tasks=1

    while [[ $# -gt 0 ]]; do
        case $1 in
            --master)
                __mongo_branch=master;
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
            --all)
                __target=all;
                shift
                ;;
            --core)
                __target=core;
                shift
                ;;
            --single-task)
                __tasks=1
                shift
                ;;
            --multi-task)
                __tasks=`cat /proc/cpuinfo | grep processor | wc -l`
                shift
                ;;
            *)
                #if [[ $1 == -* ]]; then
                #    echo "ERROR: $1 is not a supported option" 1>&2;
                #    return 1;
                #fi
                __args+=($1)
                shift
                ;;
        esac;
    done;

    #if [[ ${__mongo_branch} != master && ${__mongo_branch} != v5.0 && ${__mongo_branch} != v4.4 && ${__mongo_branch} != v4.2 && ${__mongo_branch} != v4.0 ]]; then
    #    echo "WARNING: ${__mongo_branch} is not a Git origin branch" 1>&2;
    #    read -p "Do you want to use the master branch as a reference? [y/N] ";
    #    [[ ${REPLY} =~ (y|Y) ]] && __mongo_branch=master || return 2;
    #fi
}