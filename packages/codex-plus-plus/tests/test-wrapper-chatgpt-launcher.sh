#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
WRAPPER="${PACKAGE_DIR}/codex-desktop-app-wrapper.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

make_tmpdir() {
  mktemp -d -p "${TMPDIR:-/var/tmp}" codex-plus-plus-test.XXXXXX
}

make_fake_launcher() {
  local path="$1"
  local label="$2"

  install -dm755 "$(dirname -- "${path}")"
  cat >"${path}" <<EOF
#!/usr/bin/env bash
printf '%s\n' '${label}' > "\${CODEXPP_TEST_RESULT}"
printf '%s\n' "\$@" >> "\${CODEXPP_TEST_RESULT}"
EOF
  chmod +x "${path}"
}

run_wrapper() {
  local tmpdir="$1"
  shift

  CODEXPP_CHATGPT_LAUNCHER="${tmpdir}/backup/chatgpt" \
    CODEXPP_CHATGPT_SYSTEM_LAUNCHER="${tmpdir}/system/chatgpt" \
    CODEXPP_CHATGPT_INJECTED_LAUNCHER="${tmpdir}/injected/chatgpt-injected" \
    CODEXPP_CHATGPT_BIN="${tmpdir}/native/ChatGPT" \
    CODEXPP_TEST_RESULT="${tmpdir}/result" \
    "${WRAPPER}" "$@"
}

assert_result() {
  local tmpdir="$1"
  local expected="$2"
  local actual

  actual="$(cat "${tmpdir}/result")"
  [[ "${actual}" == "${expected}" ]] || fail "expected '${expected}', got '${actual}'"
}

test_prefers_system_launcher_when_not_injected() {
  local tmpdir

  tmpdir="$(make_tmpdir)"
  trap 'rm -rf "${tmpdir}"' RETURN
  make_fake_launcher "${tmpdir}/backup/chatgpt" backup
  make_fake_launcher "${tmpdir}/system/chatgpt" system
  make_fake_launcher "${tmpdir}/native/ChatGPT" native

  run_wrapper "${tmpdir}" --remote-debugging-port=9229 codex://task/1

  assert_result "${tmpdir}" $'system\n--remote-debugging-port=9229\ncodex://task/1'
}

test_uses_backup_launcher_when_system_is_injected() {
  local tmpdir

  tmpdir="$(make_tmpdir)"
  trap 'rm -rf "${tmpdir}"' RETURN
  make_fake_launcher "${tmpdir}/backup/chatgpt" backup
  make_fake_launcher "${tmpdir}/injected/chatgpt-injected" injected
  install -dm755 "${tmpdir}/system"
  ln -s "${tmpdir}/injected/chatgpt-injected" "${tmpdir}/system/chatgpt"

  run_wrapper "${tmpdir}" --remote-allow-origins=http://127.0.0.1:9229

  assert_result "${tmpdir}" $'backup\n--remote-allow-origins=http://127.0.0.1:9229'
}

test_uses_native_binary_when_system_launcher_is_injected() {
  local tmpdir

  tmpdir="$(make_tmpdir)"
  trap 'rm -rf "${tmpdir}"' RETURN
  make_fake_launcher "${tmpdir}/injected/chatgpt-injected" injected
  make_fake_launcher "${tmpdir}/native/ChatGPT" native
  install -dm755 "${tmpdir}/system"
  ln -s "${tmpdir}/injected/chatgpt-injected" "${tmpdir}/system/chatgpt"

  run_wrapper "${tmpdir}" --remote-debugging-port=43001

  assert_result "${tmpdir}" $'native\n--remote-debugging-port=43001'
}

test_legacy_launcher_override_remains_supported() {
  local tmpdir

  tmpdir="$(make_tmpdir)"
  trap 'rm -rf "${tmpdir}"' RETURN
  make_fake_launcher "${tmpdir}/legacy/codex-desktop" legacy

  CODEXPP_OPENAI_CODEX_LAUNCHER="${tmpdir}/legacy/codex-desktop" \
    CODEXPP_CHATGPT_SYSTEM_LAUNCHER="${tmpdir}/missing/chatgpt" \
    CODEXPP_CHATGPT_INJECTED_LAUNCHER="${tmpdir}/missing/chatgpt-injected" \
    CODEXPP_CHATGPT_BIN="${tmpdir}/missing/ChatGPT" \
    CODEXPP_TEST_RESULT="${tmpdir}/result" \
    "${WRAPPER}" --remote-debugging-port=9229

  assert_result "${tmpdir}" $'legacy\n--remote-debugging-port=9229'
}

test_prefers_system_launcher_when_not_injected
test_uses_backup_launcher_when_system_is_injected
test_uses_native_binary_when_system_launcher_is_injected
test_legacy_launcher_override_remains_supported
printf 'ok - wrapper ChatGPT launcher selection\n'
