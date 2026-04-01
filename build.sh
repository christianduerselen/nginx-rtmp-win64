#!/bin/bash
# Build nginx with nginx-rtmp-module for Windows (MinGW64)
# Usage: MSYSTEM=MINGW64 bash build.sh [--skip-download]
#
# Environment variables (with defaults):
#   NGINX_VERSION     - nginx version        (default: 1.28.3)
#   RTMP_MODULE_REF   - rtmp module git ref  (default: master)
#   OPENSSL_VERSION   - OpenSSL version      (default: 3.4.0)
#   PCRE2_VERSION     - PCRE2 version        (default: 10.44)
#   ZLIB_VERSION      - zlib version         (default: 1.3.1)

set -euo pipefail

NGINX_VERSION="${NGINX_VERSION:-1.28.3}"
RTMP_MODULE_REF="${RTMP_MODULE_REF:-master}"
OPENSSL_VERSION="${OPENSSL_VERSION:-3.4.0}"
PCRE2_VERSION="${PCRE2_VERSION:-10.44}"
ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}"

SKIP_DOWNLOAD=false
if [[ "${1:-}" == "--skip-download" ]]; then
  SKIP_DOWNLOAD=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"

echo "=== nginx ${NGINX_VERSION} + rtmp module build ==="
echo "  OpenSSL: ${OPENSSL_VERSION}"
echo "  PCRE2:   ${PCRE2_VERSION}"
echo "  zlib:    ${ZLIB_VERSION}"
echo "  RTMP:    ${RTMP_MODULE_REF}"
echo "  Build:   ${BUILD_DIR}"
echo ""

# Verify toolchain
echo "--- Checking toolchain ---"
gcc --version | head -1
make --version | head -1
perl --version | head -1
echo ""

mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# ── Download sources ──────────────────────────────────────────────
if [[ "${SKIP_DOWNLOAD}" == false ]]; then

  echo "--- Downloading nginx ${NGINX_VERSION} ---"
  curl -fsSL -o nginx.tar.gz \
    "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
  tar xzf nginx.tar.gz
  echo "OK"

  echo "--- Cloning nginx-rtmp-module (${RTMP_MODULE_REF}) ---"
  rm -rf nginx-rtmp-module
  git clone --depth 1 --branch "${RTMP_MODULE_REF}" \
    https://github.com/arut/nginx-rtmp-module.git 2>/dev/null \
  || git clone https://github.com/arut/nginx-rtmp-module.git
  echo "OK"

  echo "--- Downloading PCRE2 ${PCRE2_VERSION} ---"
  curl -fsSL -o pcre2.tar.gz \
    "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VERSION}/pcre2-${PCRE2_VERSION}.tar.gz"
  tar xzf pcre2.tar.gz
  echo "OK"

  echo "--- Downloading zlib ${ZLIB_VERSION} ---"
  curl -fsSL -o zlib.tar.gz \
    "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz"
  tar xzf zlib.tar.gz
  echo "OK"

  echo "--- Downloading OpenSSL ${OPENSSL_VERSION} ---"
  curl -fsSL -o openssl.tar.gz \
    "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" \
  || curl -fsSL -o openssl.tar.gz \
    "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
  tar xzf openssl.tar.gz
  echo "OK"
  echo ""

fi

# ── Verify source directories exist ──────────────────────────────
echo "--- Verifying source directories ---"
for d in "nginx-${NGINX_VERSION}" "nginx-rtmp-module" "pcre2-${PCRE2_VERSION}" "zlib-${ZLIB_VERSION}" "openssl-${OPENSSL_VERSION}"; do
  if [[ ! -d "${d}" ]]; then
    echo "ERROR: Expected directory '${d}' not found in ${BUILD_DIR}"
    exit 1
  fi
  echo "  ${d}/ OK"
done
echo ""

# ── Patch nginx-rtmp-module for MinGW ────────────────────────────
echo "--- Patching nginx-rtmp-module for MinGW/GCC compatibility ---"
cd nginx-rtmp-module
sed -i '/typedef __int8 /d' ngx_rtmp.h
sed -i '/typedef unsigned __int8 /d' ngx_rtmp.h
find . -name '*.h' -o -name '*.c' | xargs sed -i '/#pragma warning/d'
echo "OK"
cd "${BUILD_DIR}"
echo ""

# ── Configure nginx ──────────────────────────────────────────────
echo "--- Configuring nginx ---"
cd "nginx-${NGINX_VERSION}"

# List auto/ directory to verify it exists
./configure \
  --with-cc=gcc \
  --prefix= \
  --conf-path=conf/nginx.conf \
  --pid-path=logs/nginx.pid \
  --http-log-path=logs/access.log \
  --error-log-path=logs/error.log \
  --sbin-path=nginx.exe \
  --http-client-body-temp-path=temp/client_body_temp \
  --http-proxy-temp-path=temp/proxy_temp \
  --http-fastcgi-temp-path=temp/fastcgi_temp \
  --http-scgi-temp-path=temp/scgi_temp \
  --http-uwsgi-temp-path=temp/uwsgi_temp \
  --with-cc-opt='-DFD_SETSIZE=1024 -O2 -s -Wno-error=unused-variable -Wno-error=sign-compare -Wno-error=unknown-pragmas' \
  --with-ld-opt='-static' \
  --with-pcre="../pcre2-${PCRE2_VERSION}" \
  --with-zlib="../zlib-${ZLIB_VERSION}" \
  --with-openssl="../openssl-${OPENSSL_VERSION}" \
  --with-openssl-opt='no-asm' \
  --with-http_ssl_module \
  --with-http_v2_module \
  --with-http_realip_module \
  --with-http_sub_module \
  --add-module=../nginx-rtmp-module

echo ""
echo "Configuration complete. Summary:"
grep NGX_CONFIGURE objs/ngx_auto_config.h | head -1
echo ""

# ── Build ─────────────────────────────────────────────────────────
echo "--- Building nginx ---"
make -j"$(nproc)"

echo ""
echo "Build complete. Binary:"
ls -lh objs/nginx.exe
echo ""
echo "=== SUCCESS ==="
