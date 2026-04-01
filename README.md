# nginx-win-rtmp

Windows x64 builds of [Nginx](https://nginx.org/) with the [nginx-rtmp-module](https://github.com/arut/nginx-rtmp-module), built via GitHub Actions.

## Why this exists

The official nginx Windows downloads from nginx.org do not include the RTMP module. Building nginx with third-party modules on Windows requires a specific toolchain (MSYS2/MinGW-w64) and patches for compiler compatibility.

As of April 2026, the few community projects that offer pre-built Windows binaries with the RTMP module are **not up to date**:

| Project | Nginx Version | Current Stable | Status |
|---------|--------------|----------------|--------|
| [iliweii/nginx-rtmp-win64](https://github.com/iliweii/nginx-rtmp-win64) | 1.28.1 | **1.28.3** | Single release, Jan 2025 |
| [ShiYioo/nginx-rtmp-win](https://github.com/ShiYioo/nginx-rtmp-win) | 1.28.0 | **1.28.3** | No releases, manual upload |
| [AsabaShota1995/nginx-rtmp-win64](https://github.com/AsabaShota1995/nginx-rtmp-win64) | 1.29.1 | **1.29.7** (mainline) | No releases, uses nginx-http-flv-module |

None of these projects use automated CI/CD pipelines — they are one-time manual uploads that quickly fall behind.

This repository provides a **GitHub Actions workflow** that builds any specified version of nginx with the RTMP module for Windows x64, producing a portable, statically linked binary.

## Usage

### Building via GitHub Actions

1. Push this repository to GitHub
2. Go to **Actions** → **Build Nginx with RTMP Module for Windows**
3. Click **Run workflow**
4. Configure the versions:
   - **Nginx version**: e.g., `1.28.3` (stable) or `1.29.7` (mainline)
   - **nginx-rtmp-module ref**: `master` (latest) or a tag like `v1.2.2`
   - **OpenSSL version**: e.g., `3.4.0`
   - **PCRE2 version**: e.g., `10.44`
   - **zlib version**: e.g., `1.3.1`
5. The workflow builds the binary, uploads it as an artifact, and creates a GitHub Release

### Using the built binary

1. Download and extract the zip from the GitHub Release
2. Edit `conf/nginx.conf` as needed
3. Run `nginx.exe`
4. Stream to `rtmp://localhost:1935/live/stream` using OBS, FFmpeg, etc.
5. View RTMP statistics at `http://localhost:8080/stat`

### Quick test with FFmpeg

```bash
# Stream a file
ffmpeg -re -i input.mp4 -c copy -f flv rtmp://localhost:1935/live/stream

# Play back
ffplay rtmp://localhost:1935/live/stream
```

## Build details

The workflow uses:

- **MSYS2 MinGW-w64** toolchain (GCC) on a GitHub Actions Windows runner
- **Static linking** for a portable, dependency-free binary
- All dependencies (OpenSSL, PCRE2, zlib) compiled from source
- A patch for the nginx-rtmp-module's `ngx_rtmp.h` that removes MSVC-specific `int8_t`/`uint8_t` typedefs which conflict with MinGW's `<stdint.h>`

### Configure flags

```
--with-cc=gcc
--with-cc-opt='-DFD_SETSIZE=1024 -O2 -s'
--with-ld-opt='-static'
--with-http_ssl_module
--with-http_v2_module
--with-http_realip_module
--with-http_sub_module
--add-module=nginx-rtmp-module
```

### Windows limitations of the RTMP module

Per the [upstream documentation](https://github.com/arut/nginx-rtmp-module#windows-limitations), these features are **not supported** on Windows:

- `exec` / `exec_static` directives
- Static pulls
- `auto_push`

## Checking current nginx versions

- **Stable**: https://nginx.org/en/download.html (1.28.x line)
- **Mainline**: https://nginx.org/en/download.html (1.29.x line)

## License

The build workflow in this repository is provided under the MIT License.

Nginx is licensed under the [BSD 2-Clause License](https://nginx.org/LICENSE).
The nginx-rtmp-module is licensed under the [BSD 2-Clause License](https://github.com/arut/nginx-rtmp-module/blob/master/LICENSE).
