#!/usr/bin/env bash
# 离线回归测试：验证各包 update.sh 的 pkgrel（打包修订号）判定与校验值替换逻辑。
# 从 update.sh 里原样抽出代码块，对着临时夹具跑各分支：全程不联网、不改仓库文件。
# 改动 packages/{zcode,zcode-pro,mastergo,opensquilla,qoder-cn}/update.sh 后跑：bash scripts/test-update-scripts.sh
# 抽取靠锚点（is_sha256(、current_pkgver=、sed -i、PKGBUILD_PATH}" 等），update.sh 挪动这些锚点时测试会显式失败提醒同步维护。

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

fail=0

expect() { # 实际 期望 描述
  if [[ "$1" == "$2" ]]; then
    printf '%s: 通过\n' "$3"
  else
    printf '%s: 得到 %s 期望 %s 失败\n' "$3" "$1" "$2" >&2
    fail=1
  fi
}

# 期望代码块以非 0 退出（防御类断言）。env 赋值串里的路径/十六进制值不含空格
block_fail() { # 代码 环境赋值串 描述
  if env $2 bash -c "$1" >/dev/null 2>&1; then
    printf '%s: 未报错退出 失败\n' "$3" >&2
    fail=1
  else
    printf '%s: 通过\n' "$3"
  fi
}

# 抽取代码块：begin 行起（含），end 行前止（不含）
extract_before() { # 文件 begin锚点 end锚点
  awk -v b="$2" -v e="$3" '
    index($0, b) { on = 1 }
    on && index($0, e) { exit }
    on { print }
  ' "$1"
}

# 抽取代码块：begin 行起（含），end 行止（含）
extract_through() { # 文件 begin锚点 end锚点
  awk -v b="$2" -v e="$3" '
    index($0, b) { on = 1 }
    on { print }
    on && index($0, e) { exit }
  ' "$1"
}

# 抽取代码块：begin 行起（含），end 整行精确匹配止（含）。
# 用于结束锚点是 fi/} 这类短行的场景，避免子串误命中提前截断
extract_to_exact_line() { # 文件 begin锚点 end整行内容
  awk -v b="$2" -v e="$3" '
    index($0, b) { on = 1 }
    on { print }
    on && $0 == e { exit }
  ' "$1"
}

# 抽取结果体检：必须包含全部关键片段，且不得混入 makepkg 段。
# 防止 update.sh 重排后抽取范围漂移、静默执行多余代码
check_block() { # 块 名称 必含片段...
  local block="$1" name="$2" frag
  shift 2
  for frag in "$@"; do
    if [[ "${block}" != *"${frag}"* ]]; then
      printf '%s: 抽取块缺少 %s，update.sh 结构变了，请同步维护测试锚点\n' "${name}" "${frag}" >&2
      exit 1
    fi
  done
  if [[ "${block}" == *'makepkg'* ]]; then
    printf '%s: 抽取块混入 makepkg 段，抽取边界漂移\n' "${name}" >&2
    exit 1
  fi
}

for s in \
  "${REPO_ROOT}/packages/zcode/update.sh" \
  "${REPO_ROOT}/packages/zcode-pro/update.sh" \
  "${REPO_ROOT}/packages/mastergo/update.sh" \
  "${REPO_ROOT}/packages/opensquilla/update.sh" \
  "${REPO_ROOT}/packages/qoder-cn/update.sh"; do
  bash -n "${s}" || { printf 'SYNTAX FAIL: %s\n' "${s}" >&2; exit 1; }
done
printf '语法检查: 通过（5 个脚本）\n'

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
A64=$(printf 'a%.0s' {1..64})
B64=$(printf 'b%.0s' {1..64})
C64=$(printf 'c%.0s' {1..64})
D64=$(printf 'd%.0s' {1..64})

# ---------- 夹具 ----------
cat > "${tmp}/double" <<EOF
pkgver=1.0.0
pkgrel=5
sha256sums=(
  '${A64}'
  '${B64}'
)
EOF

cat > "${tmp}/single" <<EOF
pkgver=1.0.0
pkgrel=5
sha256sums=(
  '${A64}'
)
EOF

# zcode-pro 的 PKGBUILD 用单行 sha256sums，替换锚点是整行
cat > "${tmp}/single-line" <<EOF
pkgver=1.0.0
pkgrel=5
sha256sums=('${A64}')
EOF

cat > "${tmp}/zcode" <<EOF
pkgver=3.14.5
pkgrel=7
source_x86_64=("ZCode-\${pkgver}-linux-x64.deb::https://example.com/x64.deb")
source_aarch64=("ZCode-\${pkgver}-linux-arm64.deb::https://example.com/arm64.deb")
sha256sums_x86_64=('${A64}')
sha256sums_aarch64=('${B64}')
EOF

cat > "${tmp}/broken" <<EOF
pkgver=1.0.0
pkgrel=5
sha256sums=('SKIP')
EOF

# 退化夹具：两个旧校验值相同，替换锚点失效
cat > "${tmp}/degenerate" <<EOF
pkgver=1.0.0
pkgrel=5
sha256sums=(
  '${A64}'
  '${A64}'
)
EOF

# pkgrel 非数字夹具：视为无效状态，判定应归 1
sed 's/^pkgrel=5/pkgrel=abc/' "${tmp}/double" > "${tmp}/nonum-double"
sed 's/^pkgrel=5/pkgrel=abc/' "${tmp}/single" > "${tmp}/nonum-single"
sed 's/^pkgrel=5/pkgrel=abc/' "${tmp}/single-line" > "${tmp}/nonum-single-line"
sed 's/^pkgrel=7/pkgrel=abc/' "${tmp}/zcode" > "${tmp}/nonum-zcode"

# ---------- opensquilla：is_sha256 函数与上游元数据格式校验块 ----------
isfn="$(extract_to_exact_line "${REPO_ROOT}/packages/opensquilla/update.sh" 'is_sha256()' '}')"
check_block "${isfn}" 'opensquilla is_sha256 函数' '=~ ^[0-9a-f]{64}$'
ublock="${isfn}
$(extract_to_exact_line "${REPO_ROOT}/packages/opensquilla/update.sh" 'if [[ -z "${pkgver}"' 'fi')"
check_block "${ublock}" 'opensquilla 上游校验块' 'is_sha256' 'exit 1'
expect "$(pkgver=0.5.6 dmg_sha256="$A64" whl_sha256="$B64" bash -c "${ublock}" && echo ok)" ok 'opensquilla 上游 digest 格式合法放行'
block_fail "${ublock}" "pkgver=0.5.6 dmg_sha256=not-a-digest whl_sha256=$B64" 'opensquilla 上游 digest 格式非法报错退出'

# ---------- opensquilla：判定块（含旧值防御，拼上 is_sha256 函数） ----------
oblock="${isfn}
$(extract_before "${REPO_ROOT}/packages/opensquilla/update.sh" 'current_pkgver=' 'sed -i')"
check_block "${oblock}" 'opensquilla 判定块' 'is_sha256' 'pkgrel=1' 'failed to locate distinct sha256 values'
run_o() { # 新版本 新dmg 新whl 夹具
  PKGBUILD_PATH="$4" pkgver="$1" dmg_sha256="$2" whl_sha256="$3" \
    bash -c "${oblock}; printf '%s\n' \"\${pkgrel}\""
}
expect "$(run_o 1.0.0 "$A64" "$B64" "${tmp}/double")" 5 'opensquilla 同版本双校验相同，保持'
expect "$(run_o 1.0.0 "$C64" "$B64" "${tmp}/double")" 6 'opensquilla 同版本 dmg 变，加 1'
expect "$(run_o 1.0.0 "$A64" "$C64" "${tmp}/double")" 6 'opensquilla 同版本 whl 变，加 1'
expect "$(run_o 1.1.0 "$C64" "$D64" "${tmp}/double")" 1 'opensquilla 新版本，归 1'
expect "$(run_o 1.0.0 "$A64" "$B64" "${tmp}/nonum-double")" 1 'opensquilla pkgrel 非数字，归 1'
block_fail "${oblock}" "PKGBUILD_PATH=${tmp}/broken pkgver=1.0.0 dmg_sha256=$A64 whl_sha256=$B64" 'opensquilla 提取失败报错退出，不虚增'
block_fail "${oblock}" "PKGBUILD_PATH=${tmp}/degenerate pkgver=1.0.0 dmg_sha256=$A64 whl_sha256=$B64" 'opensquilla 双旧值相同（锚点退化）报错退出'

# ---------- zcode：判定块 ----------
zblock="$(extract_before "${REPO_ROOT}/packages/zcode/update.sh" 'current_pkgver=' 'sed -i')"
check_block "${zblock}" 'zcode 判定块' 'pkgrel=1'
run_z() { # 新版本 新x64 新arm64 夹具
  PKGBUILD_PATH="$4" pkgver="$1" x64_sha256="$2" arm64_sha256="$3" \
    bash -c "${zblock}; printf '%s\n' \"\${pkgrel}\""
}
expect "$(run_z 3.14.5 "$A64" "$B64" "${tmp}/zcode")" 7 'zcode 同版本双校验相同，保持'
expect "$(run_z 3.14.5 "$C64" "$B64" "${tmp}/zcode")" 8 'zcode 同版本校验变化，加 1'
expect "$(run_z 3.14.6 "$C64" "$B64" "${tmp}/zcode")" 1 'zcode 新版本，归 1'
expect "$(run_z 3.14.5 "$A64" "$B64" "${tmp}/broken")" 1 'zcode 提取失败不虚增，归 1'
expect "$(run_z 3.14.5 "$A64" "$B64" "${tmp}/nonum-zcode")" 1 'zcode pkgrel 非数字，归 1'

# ---------- mastergo：判定块 ----------
mblock="$(extract_before "${REPO_ROOT}/packages/mastergo/update.sh" 'current_pkgver=' 'sed -i')"
check_block "${mblock}" 'mastergo 判定块' 'pkgrel=1'
run_m() { # 新版本 新校验值 夹具
  PKGBUILD_PATH="$3" pkgver="$1" source_sha256="$2" \
    bash -c "${mblock}; printf '%s\n' \"\${pkgrel}\""
}
expect "$(run_m 1.0.0 "$A64" "${tmp}/single")" 5 'mastergo 同版本同校验，保持'
expect "$(run_m 1.0.0 "$C64" "${tmp}/single")" 6 'mastergo 同版本校验变化，加 1'
expect "$(run_m 1.1.0 "$C64" "${tmp}/single")" 1 'mastergo 新版本，归 1'
expect "$(run_m 1.0.0 "$A64" "${tmp}/broken")" 1 'mastergo 提取失败不虚增，归 1'
expect "$(run_m 1.0.0 "$A64" "${tmp}/nonum-single")" 1 'mastergo pkgrel 非数字，归 1'

# ---------- zcode-pro：判定块 ----------
zpblock="$(extract_before "${REPO_ROOT}/packages/zcode-pro/update.sh" 'current_pkgver=' 'sed -i')"
check_block "${zpblock}" 'zcode-pro 判定块' 'pkgrel=1'
run_zp() { # 新版本 新校验值 夹具
  PKGBUILD_PATH="$3" pkgver="$1" source_sha256="$2" \
    bash -c "${zpblock}; printf '%s\n' \"\${pkgrel}\""
}
expect "$(run_zp 1.0.0 "$A64" "${tmp}/single-line")" 5 'zcode-pro 同版本同校验，保持'
expect "$(run_zp 1.0.0 "$C64" "${tmp}/single-line")" 6 'zcode-pro 同版本校验变化，加 1'
expect "$(run_zp 1.1.0 "$C64" "${tmp}/single-line")" 1 'zcode-pro 新版本，归 1'
expect "$(run_zp 1.0.0 "$A64" "${tmp}/broken")" 1 'zcode-pro 提取失败不虚增，归 1'
expect "$(run_zp 1.0.0 "$A64" "${tmp}/nonum-single-line")" 1 'zcode-pro pkgrel 非数字，归 1'

# ---------- qoder-cn：判定块 ----------
qblock="$(extract_before "${REPO_ROOT}/packages/qoder-cn/update.sh" 'current_pkgver=' 'sed -i')"
check_block "${qblock}" 'qoder-cn 判定块' 'pkgrel=1'
run_q() { # 新版本 新校验值 夹具
  PKGBUILD_PATH="$3" pkgver="$1" source_sha256="$2" \
    bash -c "${qblock}; printf '%s\n' \"\${pkgrel}\""
}
expect "$(run_q 1.0.0 "$A64" "${tmp}/single")" 5 'qoder-cn 同版本同校验，保持'
expect "$(run_q 1.0.0 "$C64" "${tmp}/single")" 6 'qoder-cn 同版本校验变化，加 1'
expect "$(run_q 1.1.0 "$C64" "${tmp}/single")" 1 'qoder-cn 新版本，归 1'
expect "$(run_q 1.0.0 "$A64" "${tmp}/broken")" 1 'qoder-cn 提取失败不虚增，归 1'
expect "$(run_q 1.0.0 "$A64" "${tmp}/nonum-single")" 1 'qoder-cn pkgrel 非数字，归 1'

# ---------- sed 替换流程（五个包） ----------
zchain="$(extract_through "${REPO_ROOT}/packages/zcode/update.sh" 'sed -i' 'PKGBUILD_PATH}"')"
check_block "${zchain}" 'zcode 替换链路' 's/^pkgver=' 's/^pkgrel=' 'sha256sums_x86_64=' 'sha256sums_aarch64='
cp "${tmp}/zcode" "${tmp}/zcode-run"
PKGBUILD_PATH="${tmp}/zcode-run" pkgver=3.14.6 pkgrel=1 x64_sha256="$C64" arm64_sha256="$D64" \
  x64_source_line='source_x86_64=("X64")' arm64_source_line='source_aarch64=("ARM64")' \
  bash -c "${zchain}"
zhit=$(grep -cE "^(pkgver=3.14.6|pkgrel=1|source_x86_64=\(\"X64\"\)|source_aarch64=\(\"ARM64\"\)|sha256sums_x86_64=\('$C64'\)|sha256sums_aarch64=\('$D64'\))" "${tmp}/zcode-run")
expect "${zhit}" 6 'zcode 链路一次替换六处（版本/修订/双源/双校验）'
zmd5_1="$(md5sum "${tmp}/zcode-run" | awk '{print $1}')"
PKGBUILD_PATH="${tmp}/zcode-run" pkgver=3.14.6 pkgrel=1 x64_sha256="$C64" arm64_sha256="$D64" \
  x64_source_line='source_x86_64=("X64")' arm64_source_line='source_aarch64=("ARM64")' \
  bash -c "${zchain}"
zmd5_2="$(md5sum "${tmp}/zcode-run" | awk '{print $1}')"
expect "$([[ "${zmd5_1}" == "${zmd5_2}" ]] && echo same || echo diff)" same 'zcode 链路幂等性'

mchain="$(extract_through "${REPO_ROOT}/packages/mastergo/update.sh" 'sed -i' 'PKGBUILD_PATH}"')"
check_block "${mchain}" 'mastergo 替换链路' 's/^pkgver=' 's/^pkgrel=' '0,/'
cp "${tmp}/single" "${tmp}/mastergo-run"
PKGBUILD_PATH="${tmp}/mastergo-run" pkgver=1.1.0 pkgrel=1 source_sha256="$C64" \
  bash -c "${mchain}"
mhit=$(grep -cE "^(pkgver=1.1.0|pkgrel=1)|^  '${C64}'$" "${tmp}/mastergo-run")
expect "${mhit}" 3 'mastergo 链路替换版本/修订/校验值'
mmd5_1="$(md5sum "${tmp}/mastergo-run" | awk '{print $1}')"
PKGBUILD_PATH="${tmp}/mastergo-run" pkgver=1.1.0 pkgrel=1 source_sha256="$C64" \
  bash -c "${mchain}"
mmd5_2="$(md5sum "${tmp}/mastergo-run" | awk '{print $1}')"
expect "$([[ "${mmd5_1}" == "${mmd5_2}" ]] && echo same || echo diff)" same 'mastergo 链路幂等性'

zpchain="$(extract_through "${REPO_ROOT}/packages/zcode-pro/update.sh" 'sed -i' 'PKGBUILD_PATH}"')"
check_block "${zpchain}" 'zcode-pro 替换链路' 's/^pkgver=' 's/^pkgrel=' 'sha256sums='
cp "${tmp}/single-line" "${tmp}/zcode-pro-run"
PKGBUILD_PATH="${tmp}/zcode-pro-run" pkgver=1.1.0 pkgrel=1 source_sha256="$C64" \
  bash -c "${zpchain}"
zphit=$(grep -cE "^(pkgver=1.1.0|pkgrel=1|sha256sums=\('${C64}'\))" "${tmp}/zcode-pro-run")
expect "${zphit}" 3 'zcode-pro 链路替换版本/修订/校验值'
zpmd5_1="$(md5sum "${tmp}/zcode-pro-run" | awk '{print $1}')"
PKGBUILD_PATH="${tmp}/zcode-pro-run" pkgver=1.1.0 pkgrel=1 source_sha256="$C64" \
  bash -c "${zpchain}"
zpmd5_2="$(md5sum "${tmp}/zcode-pro-run" | awk '{print $1}')"
expect "$([[ "${zpmd5_1}" == "${zpmd5_2}" ]] && echo same || echo diff)" same 'zcode-pro 链路幂等性'

qchain="$(extract_through "${REPO_ROOT}/packages/qoder-cn/update.sh" 'sed -i' 'PKGBUILD_PATH}"')"
check_block "${qchain}" 'qoder-cn 替换流程' 's/^pkgver=' 's/^pkgrel=' '0,/'
cp "${tmp}/single" "${tmp}/qoder-cn-run"
PKGBUILD_PATH="${tmp}/qoder-cn-run" pkgver=1.1.0 pkgrel=1 source_sha256="$C64" \
  bash -c "${qchain}"
qhit=$(grep -cE "^(pkgver=1.1.0|pkgrel=1)|^  '${C64}'$" "${tmp}/qoder-cn-run")
expect "${qhit}" 3 'qoder-cn 替换流程改写版本/修订/校验值'
qmd5_1="$(md5sum "${tmp}/qoder-cn-run" | awk '{print $1}')"
PKGBUILD_PATH="${tmp}/qoder-cn-run" pkgver=1.1.0 pkgrel=1 source_sha256="$C64" \
  bash -c "${qchain}"
qmd5_2="$(md5sum "${tmp}/qoder-cn-run" | awk '{print $1}')"
expect "$([[ "${qmd5_1}" == "${qmd5_2}" ]] && echo same || echo diff)" same 'qoder-cn 替换流程幂等性'

ochain="$(extract_through "${REPO_ROOT}/packages/opensquilla/update.sh" 'sed -i' 'PKGBUILD_PATH}"')"
check_block "${ochain}" 'opensquilla 替换链路' 's/^pkgver=' 's/^pkgrel=' 'current_dmg_sha256}' 'current_whl_sha256}'
cp "${tmp}/double" "${tmp}/osq-run"
osq_chain() {
  PKGBUILD_PATH="${tmp}/osq-run" pkgver=9.9.9 pkgrel=1 \
    dmg_sha256="$C64" whl_sha256="$D64" \
    current_dmg_sha256="$A64" current_whl_sha256="$B64" \
    bash -c "${ochain}"
}
osq_chain
ohit=$(grep -cE "^(pkgver=9.9.9|pkgrel=1)|^  '${C64}'$|^  '${D64}'$" "${tmp}/osq-run")
expect "${ohit}" 4 'opensquilla 链路替换版本/修订/双校验值'

# 幂等：同一输入连跑两次，文件不再变化
md5_1="$(md5sum "${tmp}/osq-run" | awk '{print $1}')"
osq_chain
md5_2="$(md5sum "${tmp}/osq-run" | awk '{print $1}')"
osq_chain
md5_3="$(md5sum "${tmp}/osq-run" | awk '{print $1}')"
expect "$([[ "${md5_1}" == "${md5_2}" && "${md5_2}" == "${md5_3}" ]] && echo same || echo diff)" same 'opensquilla 幂等性（重跑不改文件）'

exit "${fail}"
