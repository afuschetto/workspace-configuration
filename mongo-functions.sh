###
### Repository management
###

__mongo-check-workdir ()
{
    if [[ ! -d buildscripts ]]; then
        echo "ERROR: ${PWD} is not a mongo working directory" 1>&2;
        exit 1;
    fi
}

mongo-reset ()
{
    ( set -e;
    __mongo-check-workdir;

    [[ -n ${VIRTUAL_ENV} ]] && deactivate;
    git clean -fdx;
    ccache -C;

    \python3 -m venv .venv;
    .venv/bin/python3 -m pip install -r buildscripts/requirements.txt )
}

###
### Build procedures
###

# TODO: Add a parameter for --ninja (default) and --no-ninja
mongo-configure ()
{
    ( set -e;
    __check-mongo-dir;

    ./buildscripts/scons.py \
        --variables-files=etc/scons/mongodbtoolchain_stable_clang.vars \
        --opt=off \
        --dbg=on \
        --ninja generate-ninja \
        ICECC=icecc \
        CCACHE=ccache )
}

# TODO: Add a parameter for --ninja (default) and --no-ninja
mongo-build ()
{
    ( set -e;
    __mongo-check-workdir;

    [[ -f build.ninja ]] || mongo-configure;
    ninja -j400 install-all )
}

mongo-clean ()
{
    ( set -e;
    __mongo-check-workdir;

    ninja -t clean;
    ccache -c )
}

mongo-index ()
{
    ( set -e;
    __mongo-check-workdir;

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
    __mongo-check-workdir;

    ./buildscripts/clang_format.py format-my )
}

###
### Local testing
###

# TODO: Require the JS file as mandatory argument
function mongo-test {( set -e
    $(__mongo-check-workdir)

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
    $(__mongo-check-workdir)

    evergreen patch \
        --project mongodb-mongo-master \
        --finalize
)}

###
### Code review
###

# TODO: Fix stacktrace
function mongo-send-codereview {( set -e
    $(__mongo-check-workdir)

    .venv/bin/python3 ${HOME}/support/kernel-tools/codereview/upload.py \
        --git_similarity=100 \
        --check-clang-format \
        --check-eslint \
        --title "$(git log -n 1 --pretty=%B | head -n1)" \
        --cc "codereview-mongo@10gen.com,serverteam-sharding-emea@mongodb.com" \
        --jira_user "antonio.fuschetto" \
        $@
)}
