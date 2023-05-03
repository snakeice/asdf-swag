#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/swaggo/swag"
TOOL_NAME="swag"
TOOL_TEST="swag --version"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

# compare_versions compares two version strings (given as arguments). It prints
# -1, 0, or 1 if the first version is lower than, equivalent to, or higher than
# the second version.
compare_versions() {
  if [ "$1" = "$2" ]; then
    echo 0
    return
  fi

  lower=$( (
    echo "$1"
    echo "$2"
  ) | sort_versions | head -n 1)
  [ "$lower" = "$1" ] && echo -1 || echo 1
}

list_github_tags() {
  # The sed command strips prefixes “v” and “v.”. Most version tags are
  # prefixed with “v”, but some (“v.1.2.0”, “v.1.3.0”, “v.1.3.1”, and
  # “v.1.4.0”) are prefixed with “v.”. We match this with `v\.*` instead of
  # `v\.\?` for compatibility with FreeBSD sed (macOS).

  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' |
    cut -d/ -f3- |
    grep '^v' |
    sed 's/^v\.*//'
}

list_all_versions() {
  list_github_tags
}

# Through v1.4.0, Swag releases were source-only. After that point, releases
# have targetted a mixed set of of platforms and architectures:
#
# +-------------+-------------------------+-------------------------+
# |             |          Linux          |         Darwin          |
# +  Versions   +-------------------------+-------------------------+
# | (inclusive) | i386 | x86_64 | aarch64 | i386 | x86_64 | aarch64 |
# +-------------+------+--------+---------+------+--------+---------+
# |      –1.4.0 |      |        |         |      |        |         |
# +-------------+------+--------+---------+------+--------+---------+
# | 1.4.1–1.6.9 | yes  | yes    |         | yes  | yes    |         |
# +-------------+------+--------+---------+------+--------+---------+
# | 1.7.0       | yes  | yes    | yes     | yes  | yes    |         |
# +-------------+------+--------+---------+------+--------+---------+
# | 1.7.1*      | yes  | yes    | yes     |      | yes    |         |
# +-------------+------+--------+---------+------+--------+---------+
# | 1.7.3–1.8.1 | yes  | yes    | yes     |      | yes    |         |
# +-------------+------+--------+---------+------+--------+---------+
# | 1.8.2**     | yes  | yes    | yes     |      | yes    | yes     |
# +-------------+------+--------+---------+------+--------+---------+
# | 1.8.3–1.8.9 | yes  | yes    | yes     |      | yes    |         |
# +-------------+------+--------+---------+------+--------+---------+
# | 1.8.10–     | yes  | yes    | yes     |      | yes    | yes     |
# +-------------+------+--------+---------+------+--------+---------+
#
# - For release versions not denoted by an asterisk,
#   - the release archive is named swag_${version}_${platform}_${arch}.tar.gz.
#   - ${platform} is one of “Linux” or “Darwin”, and
#   - ${arch} is one of “i386”, “x86_64”, or “aarch64”.
# - For release versions denoted by one asterisk,
#   - the release archive is named swag_${platform}_${arch}.tar.gz.
#   - ${platform} is one of “linux” or “darwin”, and
#   - ${arch} is one of “386”, “amd64”, or “arm64”.
# - For release versions denoted by two asterisks,
#   - the release archive is named swag_${version}_${platform}_${arch}.tar.gz.
#   - ${platform} is one of “linux” or “darwin”, and
#   - ${arch} is one of “386”, “amd64”, or “arm64”.
#
# We expect to be able to use Darwin x86_64 binaries on Darwin aarch64 thanks
# to Rosetta 2. Otherwise, the host platform and architecture must match the
# release artifact.
#
# We completely ignore Darwin i386. Only a handful of Intel Macs were ever
# released without 64-bit support – back in 2006. No one is trying to use those
# machines for development today.
download_release() {
  local version="$1"
  local filename="$2"

  local version_slug="_$version"
  local platform="$(uname -s)"
  local detected_arch="$(uname -m)"
  local selected_arch=""

  # Broad platform/arch detection. We'll handle version-specific stuff
  # afterward so we can give more specific error messages.
  case "$platform" in
  Linux)
    case "$detected_arch" in
    i386 | x86_64 | aarch64) selected_arch="$detected_arch" ;;
    # Linux i686 should run Linux i386.
    i686) selected_arch="i386" ;;
    esac
    ;;
  Darwin)
    case "$detected_arch" in
    x86_64) selected_arch="$detected_arch" ;;
    # Darwin aarch64 call itself arm64.
    arm64) selected_arch="aarch64" ;;
    esac
    ;;
  *)
    echo "Platform $platform not supported!" 2>&1
    exit 1
    ;;
  esac

  if [ -z "$selected_arch" ]; then
    echo "Machine architecture $detected_arch not supported!" 2>&1
    exit 1
  fi

  if [ "$(compare_versions "$version" "1.4.1")" -lt 0 ]; then
    echo "Builds are only available for v1.4.1+!" 2>&1
    exit 1
  fi

  if [ "$platform" = "Linux" ] &&
    [ "$selected_arch" = "aarch64" ] &&
    [ "$(compare_versions "$version" "1.7.0")" -lt 0 ]; then
    echo "Linux AArch64 builds are only available for v1.7.0+!" 2>&1
    exit 1
  fi

  if [ "$platform" = "Darwin" ] &&
    [ "$selected_arch" = "aarch64" ] &&
    [ "$(compare_versions "$version" "1.8.2")" -ne 0 ] &&
    [ "$(compare_versions "$version" "1.8.10")" -lt 0 ]; then
    echo "Darwin AArch64 builds are only available for v1.8.2 and v1.8.10+; using x86_64." 2>&1
    selected_arch="x86_64"
  fi

  if [ "$(compare_versions "$version" "1.7.1")" -eq 0 ]; then
    version_slug=""
  fi

  if [ "$(compare_versions "$version" "1.7.1")" -eq 0 ] ||
    [ "$(compare_versions "$version" "1.8.2")" -eq 0 ]; then
    platform="$(echo "$platform" | tr '[:upper:]' '[:lower:]')"
    case "$selected_arch" in
    i386) selected_arch="386" ;;
    x86_64) selected_arch="amd64" ;;
    aarch64) selected_arch="arm64" ;;
    esac
  fi

  local url="$GH_REPO/releases/download/v${version}/swag${version_slug}_${platform}_${selected_arch}.tar.gz"

  echo "* Downloading $TOOL_NAME release $version from $url..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "$install_path"/bin
    cp -R "$ASDF_DOWNLOAD_PATH"/* "$install_path"/bin

    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    chmod +x "$install_path/bin/$tool_cmd"
    test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error occurred while installing $TOOL_NAME $version."
  )
}
