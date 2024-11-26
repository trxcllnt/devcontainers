# Log sccache server messages
export SCCACHE_ERROR_LOG="${SCCACHE_ERROR_LOG:-/var/log/devcontainer-utils/sccache.log}";
export SCCACHE_SERVER_LOG="${SCCACHE_SERVER_LOG:-sccache=info}";

# Retry failed sccache distributed compilations
export SCCACHE_DIST_RETRY_LIMIT="${SCCACHE_DIST_RETRY_LIMIT:-10}";
export SCCACHE_DIST_CONNECT_TIMEOUT="${SCCACHE_DIST_CONNECT_TIMEOUT:-15}";
export SCCACHE_DIST_REQUEST_TIMEOUT="${SCCACHE_DIST_REQUEST_TIMEOUT:-720}";

# Use sccache for Rust, C, C++, and CUDA compilations
export RUSTC_WRAPPER="${RUSTC_WRAPPER:-/usr/bin/sccache}";
export CMAKE_C_COMPILER_LAUNCHER="${CMAKE_C_COMPILER_LAUNCHER:-/usr/bin/sccache}";
export CMAKE_CXX_COMPILER_LAUNCHER="${CMAKE_CXX_COMPILER_LAUNCHER:-/usr/bin/sccache}";
export CMAKE_CUDA_COMPILER_LAUNCHER="${CMAKE_CUDA_COMPILER_LAUNCHER:-/usr/bin/sccache}";
