#! /usr/bin/env bash
set -e

NINJA_VERSION="${VERSION:-latest}";

# Ensure we're in this feature's directory during build
cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

# install global/common scripts
. ./common/install.sh;

check_packages jq wget unzip ca-certificates bash-completion;

echo "Installing ninja-build...";

if [ "${NINJA_VERSION}" = latest ]; then
    find_version_from_git_tags NINJA_VERSION https://github.com/ninja-build/ninja;
fi

_name="ninja-linux";

if test "$(uname -p)" = "aarch64"; then
    _name+="-aarch64";
fi

# Install Ninja with retries for network reliability
echo "Downloading ninja v${NINJA_VERSION}...";
wget --no-hsts -q --tries=3 --timeout=30 -O /tmp/ninja-linux.zip \
    "https://github.com/ninja-build/ninja/releases/download/v${NINJA_VERSION}/${_name}.zip" || {
    echo "ERROR: Failed to download ninja after 3 attempts";
    exit 1;
};
unzip -d /usr/bin /tmp/ninja-linux.zip;
chmod +x /usr/bin/ninja;

# Install Ninja bash completions (non-fatal if it fails)
echo "Downloading ninja bash-completion...";
wget --no-hsts -q --tries=3 --timeout=30 -O /usr/share/bash-completion/completions/ninja \
    "https://github.com/ninja-build/ninja/raw/v${NINJA_VERSION}/misc/bash-completion" || \
    echo "Warning: Failed to download ninja bash-completion (non-fatal)";

# Clean up
rm -rf /var/tmp/*;
rm -rf /var/cache/apt/*;
rm -rf /var/lib/apt/lists/*;
rm -rf /tmp/ninja-linux.zip;
