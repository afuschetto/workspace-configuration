###
### Repository management
###

function mongo-reset {
    [ -n "${VIRTUAL_ENV}" ] && deactivate
    git clean -fdx
    ccache -C

    python3 -m venv .venv
    .venv/bin/python3 -m pip install -r buildscripts/requirements.txt
}

###
### Build procedures
###

function mongo-configure {
    ./buildscripts/scons.py \
        --variables-files=etc/scons/mongodbtoolchain_stable_clang.vars \
        --ninja generate-ninja \
        --opt=off \
        --dbg=on \
        --link-model=dynamic \
        ICECC=icecc \
        CCACHE=ccache
}

function mongo-build {
    ninja -j200 install-all
}

function mongo-clean {
    ninja -t clean
    ccache -c
}

function mongo-index {
    ./buildscripts/scons.py \
        --variables-files=etc/scons/mongodbtoolchain_stable_clang.vars \
        --modules=compiledb \
        --opt=off \
        --dbg=on \
        ICECC=icecc \
        CCACHE=ccache
}

function mongo-format {
    ./buildscripts/clang_format.py format-my
}

###
### Local testing
###

###
### Code review
###


##########

# * .                         | mongo-send-evergreenpatch
# * mongo_generate_cr         | mongo-send-codereview

function mongo_run_test {
  #if [$# -eq 0]; then
  #  echo "ERROR - Missing suite name"
  #  exit 1
  #fi

  ./buildscripts/resmoke.py run \
    --mongodSetParameters='{ logComponentVerbosity: {verbosity: 2}, featureFlagToaster: true, featureFlagSpoon: true, featureFlagAuthorizationContract: true, featureFlagTenantMigrations: true, featureFlagImprovedAuditing: true, featureFlagRuntimeAuditConfig: true, featureFlagTimeseriesCollection: true, featureFlagShardingFullDDLSupport: true, featureFlagShardingFullDDLSupportTimestampedVersion: true, featureFlagWindowFunctions: true, featureFlagUseSecondaryDelaySecs: true, featureFlagChangeStreamsOptimization: true }' \
    --storageEngine=wiredTiger \
    --storageEngineCacheSizeGB=0.5 \
    --log=file \
    --jobs=1 \
    --suite=sharding \
    $@
}

function mongo_code_review {
  \python3 ~/kernel-tools/codereview/upload.py \
    --git_similarity=100 \
    --check-clang-format \
    --check-eslint \
    --server "mongodbcr.appspot.com" -H "mongodbcr.appspot.com" \
    --jira_user "antonio.fuschetto" \
    --title "$(git log -n 1 --pretty=%B | head -n1)" \
    --cc "codereview-mongo@10gen.com,serverteam-sharding-emea@mongodb.com" \
    $@
}
