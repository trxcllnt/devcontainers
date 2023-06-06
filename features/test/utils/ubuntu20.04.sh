#! /usr/bin/env bash

# This test can be run with the following command (from the root of this repo)
# ```
# npx --package=@devcontainers/cli -c 'devcontainer features test \
#     --features cuda \
#     --base-image ubuntu:22.04 .'
# ```

set -ex

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

>&2 echo "PATH=$PATH"
>&2 echo "BASH_ENV=$BASH_ENV"
>&2 echo "user=$(whoami)"
export VAULT_S3_TTL="${VAULT_S3_TTL:-"3600s"}";

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.
check "post-attach-command.sh exists" stat /opt/devcontainer/bin/post-attach-command.sh

reset_state() {
    export GH_TOKEN=;
    export VAULT_HOST=;
    export SCCACHE_BUCKET=;
    export SCCACHE_REGION=;
    export AWS_ACCESS_KEY_ID=;
    export AWS_SESSION_TOKEN=;
    export AWS_SECRET_ACCESS_KEY=;
    export -n GH_TOKEN;
    export -n VAULT_HOST;
    export -n SCCACHE_BUCKET;
    export -n SCCACHE_REGION;
    export -n AWS_ACCESS_KEY_ID;
    export -n AWS_SESSION_TOKEN;
    export -n AWS_SECRET_ACCESS_KEY;
    unset GH_TOKEN;
    unset VAULT_HOST;
    unset SCCACHE_BUCKET;
    unset SCCACHE_REGION;
    unset AWS_ACCESS_KEY_ID;
    unset AWS_SESSION_TOKEN;
    unset AWS_SECRET_ACCESS_KEY;
    devcontainer-utils-vault-s3-export "1";
}

write_bad_creds() {
    SCCACHE_BUCKET="bad_sccache_bucket"               \
    SCCACHE_REGION="bad_sccache_region"               \
    AWS_ACCESS_KEY_ID="bad_aws_access_key_id"         \
    AWS_SESSION_TOKEN="bad_aws_session_token"         \
    AWS_SECRET_ACCESS_KEY="bad_aws_secret_access_key" \
    devcontainer-utils-vault-s3-export "0";
}

write_good_creds() {
    SCCACHE_BUCKET="${sccache_bucket_ci:-}"            \
    SCCACHE_REGION="${sccache_region_ci:-}"            \
    AWS_ACCESS_KEY_ID="${aws_access_key_id:-}"         \
    AWS_SESSION_TOKEN="${aws_session_token:-}"         \
    AWS_SECRET_ACCESS_KEY="${aws_secret_access_key:-}" \
    devcontainer-utils-vault-s3-export "0";
}

expect_s3_cache_is_used() {
    local bucket="${SCCACHE_BUCKET:-"$(grep 'bucket=' ~/.aws/config 2>/dev/null | sed 's/bucket=//' || echo)"}";
    local region="${SCCACHE_REGION:-"$(grep 'region=' ~/.aws/config 2>/dev/null | sed 's/region=//' || echo "${AWS_DEFAULT_REGION:-}")"}";
    local output="$(                    \
    sccache --stop-server 2>&1 || true  \
 && SCCACHE_NO_DAEMON=1                 \
    SCCACHE_BUCKET=${bucket}            \
    SCCACHE_REGION=${region}            \
    sccache --show-stats 2>&1)"; \
    echo "output:"; echo "${output}";
    grep -qE 'Cache location \s+ s3' <<< "${output}";
}

export -f expect_s3_cache_is_used;

expect_local_disk_cache_is_used() {
    local bucket="${SCCACHE_BUCKET:-"$(grep 'bucket=' ~/.aws/config 2>/dev/null | sed 's/bucket=//' || echo)"}";
    local region="${SCCACHE_REGION:-"$(grep 'region=' ~/.aws/config 2>/dev/null | sed 's/region=//' || echo "${AWS_DEFAULT_REGION:-}")"}";
    local output="$(                    \
    sccache --stop-server 2>&1 || true  \
 && SCCACHE_NO_DAEMON=1                 \
    SCCACHE_BUCKET=${bucket}            \
    SCCACHE_REGION=${region}            \
    sccache --show-stats 2>&1)"; \
    echo "output:"; echo "${output}";
    grep -qE 'Cache location \s+ Local disk' <<< "${output}";
}

export -f expect_local_disk_cache_is_used;

if test -n "${sccache_bucket_ci:-}"; then

    reset_state                            \
 && SCCACHE_BUCKET="${sccache_bucket_ci}"  \
    SCCACHE_REGION="${sccache_region_ci}"  \
    devcontainer-utils-post-attach-command ;
    check "no creds with SCCACHE_BUCKET uses local disk cache" expect_local_disk_cache_is_used;

    reset_state                            \
 && write_bad_creds                        \
 && SCCACHE_BUCKET="${sccache_bucket_ci}"  \
    SCCACHE_REGION="${sccache_region_ci}"  \
    devcontainer-utils-post-attach-command ;
    check "bad creds and config and no VAULT_HOST uses local disk cache" expect_local_disk_cache_is_used;

    reset_state                            \
 && write_bad_creds                        \
 && SCCACHE_BUCKET="${sccache_bucket_ci}"  \
    SCCACHE_REGION="${sccache_region_ci}"  \
    devcontainer-utils-post-attach-command ;
    check "bad creds with SCCACHE_BUCKET and no VAULT_HOST uses local disk cache" expect_local_disk_cache_is_used;

    if test -n "${aws_access_key_id:-}" \
    && test -n "${aws_secret_access_key:-}"; then
        reset_state                            \
     && write_good_creds                       \
     && devcontainer-utils-post-attach-command ;
        check "existing creds and config uses S3 cache" expect_s3_cache_is_used;

        reset_state                                            \
     && sccache_bucket_ci= sccache_region_ci= write_good_creds \
     && SCCACHE_BUCKET="${sccache_bucket_ci}"                  \
        SCCACHE_REGION="${sccache_region_ci}"                  \
        devcontainer-utils-post-attach-command                 ;
        check "Existing creds and config with SCCACHE_BUCKET uses S3 cache" expect_s3_cache_is_used;

    fi
fi

if test -n "${vault_host:-}" \
&& test -n "${sccache_bucket_gh:-}"; then
    reset_state                            \
 && VAULT_HOST="${vault_host}"             \
    devcontainer-utils-post-attach-command ;
    check "VAULT_HOST with no SCCACHE_BUCKET uses local disk cache" expect_local_disk_cache_is_used;

    if test -n "${gh_token:-}"; then
        reset_state                            \
     && GH_TOKEN="${gh_token}"                 \
        VAULT_HOST="${vault_host}"             \
        SCCACHE_BUCKET="${sccache_bucket_gh}"  \
        SCCACHE_REGION="${sccache_region_gh}"  \
        devcontainer-utils-post-attach-command ;
        check "no creds with GH_TOKEN, VAULT_HOST, and SCCACHE_BUCKET should generate credentials" expect_s3_cache_is_used;

        reset_state                            \
     && write_bad_creds                        \
     && GH_TOKEN="${gh_token}"                 \
        VAULT_HOST="${vault_host}"             \
        SCCACHE_BUCKET="${sccache_bucket_gh}"  \
        SCCACHE_REGION="${sccache_region_gh}"  \
        devcontainer-utils-post-attach-command ;
        check "bad stored creds with GH_TOKEN, VAULT_HOST, and SCCACHE_BUCKET should regenerate credentials" expect_s3_cache_is_used;

        reset_state                                       \
     && GH_TOKEN="${gh_token}"                            \
        VAULT_HOST="${vault_host}"                        \
        SCCACHE_BUCKET="${sccache_bucket_gh}"             \
        SCCACHE_REGION="${sccache_region_gh}"             \
        AWS_ACCESS_KEY_ID="bad_aws_access_key_id"         \
        AWS_SESSION_TOKEN="bad_aws_session_token"         \
        AWS_SECRET_ACCESS_KEY="bad_aws_secret_access_key" \
        devcontainer-utils-post-attach-command            ;
        check "bad envvar creds with GH_TOKEN, VAULT_HOST, and SCCACHE_BUCKET should regenerate credentials" expect_s3_cache_is_used;
    fi
fi

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
