#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_PATH="${SCRIPT_DIR}/PKGBUILD"
SRCINFO_PATH="${SCRIPT_DIR}/.SRCINFO"
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/deepnight/ldtk.git}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing dependency: %s\n' "$1" >&2
    exit 1
  fi
}

require_command awk
require_command git
require_command makepkg
require_command sed

current_pkgver=""
if [[ -f "${PKGBUILD_PATH}" ]]; then
  current_pkgver="$(awk -F= '/^pkgver=/ {print $2; exit}' "${PKGBUILD_PATH}")"
fi

upstream_head="$(git ls-remote "${UPSTREAM_URL}" HEAD | awk '{print $1}')"
if [[ -z "${upstream_head}" ]]; then
  printf 'failed to resolve upstream HEAD\n' >&2
  exit 1
fi

# PKGBUILD 记录的是 7 位缩写 hash，前缀一致即视为同一提交，无需 clone
if [[ "${current_pkgver}" == *".g${upstream_head:0:7}" ]]; then
  printf 'ldtk-git already at %s\n' "${current_pkgver}"
  exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

# 只需要 git 元数据计算 describe，不下载源码构建
git clone --bare --quiet "${UPSTREAM_URL}" "${tmpdir}/ldtk.git"

describe_raw="$(git --git-dir="${tmpdir}/ldtk.git" describe --long --tags --abbrev=7 2>/dev/null || true)"
if [[ -n "${describe_raw}" ]]; then
  new_pkgver="$(printf '%s\n' "${describe_raw}" | sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g')"
else
  # 上游无 tag 时退化为纯提交号
  new_pkgver="0.r0.g${upstream_head:0:7}"
fi

sed -i \
  -e "s/^pkgver=.*/pkgver=${new_pkgver}/" \
  -e "s/^pkgrel=.*/pkgrel=1/" \
  "${PKGBUILD_PATH}"

(
  cd "${SCRIPT_DIR}"
  makepkg --printsrcinfo > "${SRCINFO_PATH}"
)

printf 'updated ldtk-git to %s\n' "${new_pkgver}"
