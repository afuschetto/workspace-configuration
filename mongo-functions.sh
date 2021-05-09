###
### Repository management
###

# Reset the working directory to its initial state, as if the repository had
# just been cloned and its Python virtual environment properly created and
# initialized.
#
# Quality level: Successfully tested with branches 4.4 and higher.
# TODO: * Add '--use-feature=2020-resolver' argument to the 'pip install'
#         command as required for branches 4.0 and 4.2.
mongo-reset ()
{
    ( set -e;
    __mongo-check-wrkdir;

    [[ -n ${VIRTUAL_ENV} ]] && deactivate;
    git clean -fdx;
    ccache -C;

    \python3 -m venv .venv;
    .venv/bin/python3 -m pip install -r buildscripts/requirements.txt )
}

###
### Build procedures
###

# Generate the configuration file required by the Ninja build system. Such
# configuration is automatically generated or updated when "mongo-build" is run,
# however this function must be explicitly executed when a SCons configuration
# file changes (e.g., after adding or removing a source file to the project).
#
# Quality level: Successfully tested with branches 4.4 and higher.
# TODO: * Inhibit the execution for branches 4.0 and 4.2.
mongo-configure ()
{
    ( set -e;
    __mongo-check-wrkdir;

    ./buildscripts/scons.py \
        --variables-files=etc/scons/mongodbtoolchain_stable_clang.vars \
        --opt=off \
        --dbg=on \
	--link-model=dynamic \
        --ninja generate-ninja \
        ICECC=icecc \
        CCACHE=ccache )
}

# Build the mongo project taking care of the environment configuration
# (mongo-configure) when required.
#
# Options:
#   --ninja:    Leverage the Ninja build system to spread and orchestrate the
#               build across a large set of hosts. The feature is fully
#               supported starting with version 4.4 of mongo. This option is
#               enabled by default.
#   --no-ninja: Do not take advantage of the Ninja build system and the build
#               runs only on the local host. This option is mandatory to build
#               version 4.2 of mongo.
#
# Quality level: Successfully tested with branches 4.2 and higher.
# TODO: * Suppor branch 4.0
mongo-build ()
{
    ( set -e;
    __mongo-check-wrkdir;

    __mongo-parse-args $@;
    if ${__use_ninja}; then
        [[ -f build.ninja ]] || mongo-configure;
        ninja -j400 install-all;
    else
        ./buildscripts/scons.py \
	    --variables-files=etc/scons/mongodbtoolchain_stable_clang.vars \
	    --opt=off \
	    --dbg=on \
	    ICECC=icecc;
    fi )
}

mongo-clean ()
{
    ( set -e;
    __mongo-check-wrkdir;

    ninja -t clean;
    ccache -c )
}

mongo-index ()
{
    ( set -e;
    __mongo-check-wrkdir;

    ./buildscripts/scons.py \
        --variables-files=etc/scons/mongodbtoolchain_stable_clang.vars \
        --opt=off \
        --dbg=on \
        --modules=compiledb \
        ICECC=icecc \
        CCACHE=ccache )
}

mongo-format ()
{
    ( set -e;
    __mongo-check-wrkdir;

    ./buildscripts/clang_format.py format-my )
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
    __use_ninja=true;
    while [[ $# -gt 0 ]]; do
        case $1 in
            --ninja)
                __use_ninja=true;
                shift
            ;;
            --no-ninja)
                __use_ninja=false;
                shift
            ;;
            *)
                echo "ERROR: $1 is not a supported parameter" 1>&2;
                exit 1
            ;;
        esac;
    done
}
