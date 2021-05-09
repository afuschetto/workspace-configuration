###
### Repository management
###

# Reset the working directory to its initial state, as if the repository had
# just been cloned and its Python virtual environment created and properly
# initialized.
mongo-reset ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args $@;

    echo "WARNING: All uncommitted changes and unversioned files will be lost";
    read -p "Are you sure you want to proceed? [y/N] ";
    [[ ${REPLY} =~ (y|Y) ]] || exit 0;

    [[ -n ${VIRTUAL_ENV} ]] && deactivate;
    \git clean -fdx;
    ccache -C;

    case ${__mongo_branch} in
        v4.4 | master)
            \python3 -m venv .venv;
            .venv/bin/python3 -m pip install -r buildscripts/requirements.txt
            ;;
        v4.2)
            \python3 -m venv .venv;
            .venv/bin/python3 -m pip install -r buildscripts/requirements.txt --use-feature=2020-resolver
            ;;
        v4.0)
            \virtualenv -p python2 .venv;
            .venv/bin/python2 -m pip install -r buildscripts/requirements.txt --use-feature=2020-resolver
            ;;
        *)
            echo "ERROR: ${__mongo_branch} branch is not supported by this command" 1>&2;
            exit 1
            ;;
    esac )
}

###
### Build
###

# Generate the configuration file required for the distributed build (Ninja
# build system. This configuration is automatically generated or updated when
# the "mongo-build" command is run. However, this command must be explicitly
# invoked when a SCons configuration file changes (e.g., after adding or
# removing a source file from the project).
# TODO: * What's the ICECC argumet?
mongo-configure ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args $@;

    case ${__mongo_branch} in
        v4.4 | master)
            ./buildscripts/scons.py \
                --variables-files=etc/scons/mongodbtoolchain_stable_${__toolchain}.vars \
                --opt=off \
                --dbg=on \
                --link-model=dynamic \
                --ninja generate-ninja \
                ICECC=icecc \
                CCACHE=ccache
            ;;
        *)
            echo "ERROR: ${__mongo_branch} branch is not supported by this command" 1>&2;
            exit 1
            ;;
    esac )
}

# Build the mongo project taking care of the environment configuration when
# needed ("mongo-configure" command) and enabling the distributed build if
# supported by the branch.
# TODO: * Validate steps for v4.2 and v4.0
mongo-build ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args $@;

    case ${__mongo_branch} in
        v4.4 | master)
            [[ -f build.ninja ]] || mongo-configure $@;
            ninja -j400 install-all
            ;;
        v4.2 | v4.0)
            ./buildscripts/scons.py \
                --variables-files=etc/scons/mongodbtoolchain_stable_${__toolchain}.vars \
                --opt=off \
                --dbg=on \
                ICECC=icecc \
                mongod mongos
            ;;
        *)
            echo "ERROR: ${__mongo_branch} branch is not supported by this command" 1>&2;
            exit 1
            ;;
    esac )
}

# Delete all files that are created by the "mongo-build" command (i.e., object
# and target files). However, do not delete files that record the configuration
# (e.g., build.ninja).
mongo-clean ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args $@;

    case ${__mongo_branch} in
        v4.4 | master)
            ninja -t clean;
            ccache -c
            ;;
        v4.2 | v4.0)
            ./buildscripts/scons.py \
                --variables-files=etc/scons/mongodbtoolchain_stable_${__toolchain}.vars \
                --clean \
                mongod mongos
            ;;
        *)
            echo "ERROR: ${__mongo_branch} branch is not supported by this command" 1>&2;
            exit 1
            ;;
    esac )
}

# TODO: Is it really required?
mongo-index ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args $@;

    case ${__mongo_branch} in
        v4.4 | master)
            ./buildscripts/scons.py \
                --variables-files=etc/scons/mongodbtoolchain_stable_${__toolchain}.vars \
                --opt=off \
                --dbg=on \
                --modules=compiledb \
                ICECC=icecc \
                CCACHE=ccache
            ;;
        v4.2 | v4.0)
            ./buildscripts/scons.py \
                --variables-files=etc/scons/mongodbtoolchain_stable_${__toolchain}.vars \
                --opt=off \
                --dbg=on \
                --modules=compiledb \
                ICECC=icecc
            ;;
        *)
            echo "ERROR: ${__mongo_branch} branch is not supported by this command" 1>&2;
            exit 1
            ;;
    esac )
}

# Format the source code according to a company-wide clang-format configuration.
# TODO: What are the differences between format-my and format?
mongo-format ()
{
    ( set -e;
    __mongo-check-wrkdir;
    __mongo-parse-args $@;

    case ${__mongo_branch} in
        v4.4 | master)
            ./buildscripts/clang_format.py format-my
            ;;
        v4.2 | v4.0)
            ./buildscripts/clang_format.py format
            ;;
        *)
            echo "ERROR: ${__mongo_branch} branch is not supported by this command" 1>&2;
            exit 1
            ;;
    esac )
}

###
### Local testing
###

# TODO: Require the JS file as mandatory argument
function mongo-test {( set -e
    $(__mongo-check-wrkdir)

    ./buildscripts/resmoke.py run \
        --storageEngine=wiredTiger \
        --storageEngineCacheSizeGB=0.5 \
        --jobs=1 \
        --log=file \
        --suite=sharding \
        $@
)}

###
### Remote testing
###

# TODO: Find a way to automatically set the patch summary including the patch set number
function mongo-send-evergreenpatch {( set -e
    $(__mongo-check-wrkdir)

    evergreen patch \
        --project mongodb-mongo-master \
        --finalize
)}

###
### Code review
###

# TODO: Fix stacktrace
function mongo-send-codereview {( set -e
    $(__mongo-check-wrkdir)

    .venv/bin/python3 ${HOME}/support/kernel-tools/codereview/upload.py \
        --git_similarity=100 \
        --check-clang-format \
        --check-eslint \
        --title "$(git log -n 1 --pretty=%B | head -n1)" \
        --cc "codereview-mongo@10gen.com,serverteam-sharding-emea@mongodb.com" \
        --jira_user "antonio.fuschetto" \
        $@
)}

###
### Utilities
###

__mongo-check-wrkdir ()
{
    if [[ ! -d buildscripts ]]; then
        echo "ERROR: ${PWD} is not a mongo working directory" 1>&2;
        exit 1;
    fi
}

__mongo-parse-args ()
{
    __mongo_branch=`git rev-parse --abbrev-ref HEAD`;
    __toolchain=clang

    while [[ $# -gt 0 ]]; do
        case $1 in
            --master)
                __mongo_branch=master;
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
            *)
                echo "ERROR: $1 is not a supported parameter" 1>&2;
                exit 1
                ;;
        esac;
    done;

    if [[ ${__mongo_branch} != master && ${__mongo_branch} != v4.4 && ${__mongo_branch} != v4.2 && ${__mongo_branch} != v4.0 ]]; then
        echo "WARNING: ${__mongo_branch} is not a Git origin branch" 1>&2;
        read -p "Do you want to use the master branch as a reference? [y/N] ";
        [[ ${REPLY} =~ (y|Y) ]] && __mongo_branch=master || exit 2;
    fi
}
