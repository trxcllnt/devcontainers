#! /usr/bin/env bash

append_envvar() {
    if [ -n "${1:-}" ]; then
        for file in ~/.bashrc /etc/profile.d/*-devcontainer-utils.sh; do
            echo "export ${1}=\"${2:-}\";" | sudo tee -a "${file}" >/dev/null;
        done;
    fi
}

remove_envvar() {
    if [ -n "${1:-}" ]; then
        for file in ~/.bashrc /etc/profile.d/*-devcontainer-utils.sh; do
            if grep -q -E "^export ${1}=.*$" "${file}"; then
                sudo sed -Ei "/^export ${1}=.*\$/d" "${file}";
            fi
        done
    fi
}

test_s3_creds_and_update_envvars() {

    set -euo pipefail;

    # PS4="+ ${BASH_SOURCE[0]}:\${LINENO} "; set -x;

    remove_envvar "SCCACHE_BUCKET";
    remove_envvar "SCCACHE_REGION";
    remove_envvar "SCCACHE_S3_NO_CREDENTIALS";

    local file;

    for file in ~/.bashrc /etc/profile.d/*-devcontainer-utils.sh; do
        sudo sed -Ei '/^unset SCCACHE_BUCKET;$/d' "${file}";
        sudo sed -Ei '/^unset SCCACHE_REGION;$/d' "${file}";
        sudo sed -Ei '/^unset AWS_ACCESS_KEY_ID;$/d' "${file}";
        sudo sed -Ei '/^unset AWS_SESSION_TOKEN;$/d' "${file}";
        sudo sed -Ei '/^unset AWS_SECRET_ACCESS_KEY;$/d' "${file}";
    done

    local bucket="${SCCACHE_BUCKET:-"$(grep 'bucket=' ~/.aws/config 2>/dev/null | sed 's/bucket=//' || echo)"}";
    local region="${SCCACHE_REGION:-"$(grep 'region=' ~/.aws/config 2>/dev/null | sed 's/region=//' || echo "${AWS_DEFAULT_REGION:-}")"}";
    local aws_access_key_id="${AWS_ACCESS_KEY_ID:-"$(grep 'aws_access_key_id=' ~/.aws/credentials 2>/dev/null | sed 's/aws_access_key_id=//' || echo)"}";
    local aws_session_token="${AWS_SESSION_TOKEN:-"$(grep 'aws_session_token=' ~/.aws/credentials 2>/dev/null | sed 's/aws_session_token=//' || echo)"}";
    local aws_secret_access_key="${AWS_SECRET_ACCESS_KEY:-"$(grep 'aws_secret_access_key=' ~/.aws/credentials 2>/dev/null | sed 's/aws_secret_access_key=//' || echo)"}";

    local s3_status="${1:-$(                              \
        SCCACHE_BUCKET=${bucket}                          \
        SCCACHE_REGION=${region}                          \
        AWS_ACCESS_KEY_ID=${aws_access_key_id}            \
        AWS_SESSION_TOKEN=${aws_session_token}            \
        AWS_SECRET_ACCESS_KEY=${aws_secret_access_key}    \
        devcontainer-utils-vault-s3-test >/dev/null 2>&1; \
        echo $?;                                          \
    )}";

    use_aws_config_vars() {
        append_envvar "SCCACHE_BUCKET" "${bucket}";
        append_envvar "SCCACHE_REGION" "${region}";

        mkdir -p ~/.aws;

        cat <<EOF > ~/.aws/config
[default]
${bucket:+"bucket=${bucket}"}
${region:+"region=${region}"}
EOF

        cat <<EOF > ~/.aws/credentials
[default]
aws_access_key_id=${aws_access_key_id}
aws_session_token=${aws_session_token}
aws_secret_access_key=${aws_secret_access_key}
EOF

        chmod 0600 ~/.aws/{config,credentials};
    }

    case $s3_status in
        [0] ) # bucket is read + write
            use_aws_config_vars;
            # install a crontab to refresh creds
            if ! crontab -l >/dev/null 2>&1; then
                crontab -u $(whoami) /opt/devcontainer/cron/vault-s3-init;
                sudo cron;
            fi
            ;;
        [2] ) # bucket is read-only
            use_aws_config_vars;
            append_envvar "SCCACHE_S3_NO_CREDENTIALS" "1";
            ;;
          * ) # bucket is inaccessible
            rm -f ~/.aws/{config,credentials};
            for file in ~/.bashrc /etc/profile.d/*-devcontainer-utils.sh; do
                echo "unset SCCACHE_BUCKET;" | sudo tee -a "${file}" >/dev/null;
                echo "unset SCCACHE_REGION;" | sudo tee -a "${file}" >/dev/null;
                echo "unset AWS_ACCESS_KEY_ID;" | sudo tee -a "${file}" >/dev/null;
                echo "unset AWS_SESSION_TOKEN;" | sudo tee -a "${file}" >/dev/null;
                echo "unset AWS_SECRET_ACCESS_KEY;" | sudo tee -a "${file}" >/dev/null;
            done
            ;;
    esac
}

(test_s3_creds_and_update_envvars "$@");

. /etc/profile.d/*-devcontainer-utils.sh;
