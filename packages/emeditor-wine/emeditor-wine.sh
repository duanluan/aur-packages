#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
pkgname="${EMEDITOR_WINE_PACKAGE_NAME:-emeditor-wine}"
pkgver="${EMEDITOR_WINE_VERSION:-26.2.7}"
archive_name="EmEditor_v${pkgver}.7z"
archive_sha256="${EMEDITOR_WINE_ARCHIVE_SHA256:-b48dcfc073bf1af566cea02e09162ba134cf0f4f4cb5d46ebf0209cea8665945}"
prefix="${EMEDITOR_WINEPREFIX:-${HOME}/.wine-emeditor}"
wine_user="${USER:-$(id -un)}"
app="${prefix}/drive_c/users/${wine_user}/AppData/Local/Programs/EmEditor/EmEditor.exe"
ui_font="${EMEDITOR_WINE_UI_FONT:-Noto Sans CJK SC}"
lang="${EMEDITOR_WINE_LANG:-zh_CN.UTF-8}"
desktop_exec="${EMEDITOR_WINE_DESKTOP_EXEC:-emeditor-wine}"
refresh_mode="${EMEDITOR_WINE_REFRESH_MODE:-wm}"
directwrite="${EMEDITOR_WINE_DIRECTWRITE:-0}"
tray_icon="${EMEDITOR_WINE_TRAY_ICON:-0}"
package_archive="/usr/share/${pkgname}/${archive_name}"

validate_options() {
  case "${refresh_mode}" in
    default | wm | focus | desktop) ;;
    *)
      printf 'invalid EMEDITOR_WINE_REFRESH_MODE: %s\n' "${refresh_mode}" >&2
      printf 'expected one of: default, wm, focus, desktop\n' >&2
      exit 1
      ;;
  esac

  case "${directwrite}" in
    0 | 1) ;;
    *)
      printf 'invalid EMEDITOR_WINE_DIRECTWRITE: %s\n' "${directwrite}" >&2
      printf 'expected 0 or 1\n' >&2
      exit 1
      ;;
  esac

  case "${tray_icon}" in
    0 | 1) ;;
    *)
      printf 'invalid EMEDITOR_WINE_TRAY_ICON: %s\n' "${tray_icon}" >&2
      printf 'expected 0 or 1\n' >&2
      exit 1
      ;;
  esac
}

verify_archive() {
  local file="$1"
  local actual

  actual="$(sha256sum "${file}" | awk '{print $1}')"
  [[ "${actual}" == "${archive_sha256}" ]]
}

resolve_archive() {
  local candidate

  for candidate in "${EMEDITOR_WINE_ARCHIVE:-}" "${package_archive}"; do
    [[ -n "${candidate}" && -f "${candidate}" ]] || continue
    if verify_archive "${candidate}"; then
      printf '%s\n' "${candidate}"
      return 0
    fi
    printf 'ignoring archive with unexpected checksum: %s\n' "${candidate}" >&2
  done

  printf 'missing EmEditor archive: %s\n' "${package_archive}" >&2
  return 1
}

pick_dpi() {
  if [[ -n "${EMEDITOR_WINE_DPI:-}" ]]; then
    printf '%s\n' "${EMEDITOR_WINE_DPI}"
    return
  fi

  local xft line width pxw mmw phys dpi
  if command -v xrdb >/dev/null 2>&1; then
    xft="$(xrdb -query 2>/dev/null | awk '$1 == "Xft.dpi:" {print int($2 + 0.5); exit}' || true)"
  else
    xft=""
  fi

  if command -v xrandr >/dev/null 2>&1; then
    line="$(xrandr --listmonitors 2>/dev/null | awk 'NR == 2 {print $0}' || true)"
  else
    line=""
  fi
  width="$(printf '%s\n' "${line}" | sed -n 's/.* \([0-9][0-9]*\)\/\([0-9][0-9]*\)x.*/\1 \2/p')"
  pxw="${width%% *}"
  mmw="${width##* }"
  phys=0

  if [[ "${pxw}" =~ ^[0-9]+$ && "${mmw}" =~ ^[0-9]+$ && "${mmw}" -gt 0 ]]; then
    phys="$(( (pxw * 254 + mmw * 5) / (mmw * 10) ))"
  fi

  dpi="${xft:-96}"
  if [[ "${phys}" -gt "${dpi}" ]]; then
    dpi="${phys}"
  fi

  if [[ "${pxw}" =~ ^[0-9]+$ && "${pxw}" -ge 3800 && "${dpi}" -lt 192 ]]; then
    dpi=192
  elif [[ "${dpi}" -ge 220 ]]; then
    dpi=240
  elif [[ "${dpi}" -ge 170 ]]; then
    dpi=192
  elif [[ "${dpi}" -ge 130 ]]; then
    dpi=168
  else
    dpi=120
  fi

  printf '%s\n' "${dpi}"
}

pick_desktop_size() {
  if [[ -n "${EMEDITOR_WINE_DESKTOP_SIZE:-}" ]]; then
    printf '%s\n' "${EMEDITOR_WINE_DESKTOP_SIZE}"
    return
  fi

  local line size
  if command -v xrandr >/dev/null 2>&1; then
    line="$(xrandr --listmonitors 2>/dev/null | awk 'NR == 2 {print $0}' || true)"
  else
    line=""
  fi

  size="$(printf '%s\n' "${line}" | sed -n 's/.* \([0-9][0-9]*\)\/[0-9][0-9]*x\([0-9][0-9]*\)\/[0-9][0-9]*.*/\1x\2/p')"
  if [[ "${size}" =~ ^[0-9]+x[0-9]+$ ]]; then
    printf '%s\n' "${size}"
  else
    printf '1600x1000\n'
  fi
}

hex_utf16le() {
  printf '%s' "$1" | iconv -f UTF-8 -t UTF-16LE | od -An -tx1 -v | tr -d ' \n'
}

zero_hex() {
  local bytes="$1"
  local out=""
  while ((bytes > 0)); do
    out="${out}00"
    bytes=$((bytes - 1))
  done
  printf '%s' "${out}"
}

set_logfont() {
  local value="$1"
  local height="$2"
  local facehex padchars padhex common fonthex

  facehex="$(hex_utf16le "${ui_font}")"
  padchars=$((32 - ${#ui_font}))
  if ((padchars < 0)); then
    padchars=0
  fi
  padhex="$(zero_hex $((padchars * 2)))"
  common="000000000000000000000000900100000000008600000000${facehex}${padhex}"
  fonthex="${height}${common}"
  wine reg add 'HKCU\Control Panel\Desktop\WindowMetrics' /v "${value}" /t REG_BINARY /d "${fonthex}" /f >/dev/null
}

configure_prefix() {
  local dpi="$1"

  wine reg add 'HKCU\Software\EmSoft\EmEditor v3\Common' /v UseDirectWrite /t REG_DWORD /d "${directwrite}" /f >/dev/null
  wine reg add 'HKCU\Software\EmSoft\EmEditor v3\Common' /v TrayIcon /t REG_DWORD /d "${tray_icon}" /f >/dev/null
  wine reg add 'HKCU\Software\Wine\X11 Driver' /v Managed /t REG_SZ /d Y /f >/dev/null
  if [[ "${refresh_mode}" == "wm" || "${refresh_mode}" == "focus" ]]; then
    wine reg add 'HKCU\Software\Wine\X11 Driver' /v Decorated /t REG_SZ /d Y /f >/dev/null
  else
    wine reg add 'HKCU\Software\Wine\X11 Driver' /v Decorated /t REG_SZ /d N /f >/dev/null
  fi
  if [[ "${refresh_mode}" == "focus" ]]; then
    wine reg add 'HKCU\Software\Wine\X11 Driver' /v UseTakeFocus /t REG_SZ /d N /f >/dev/null
  else
    wine reg delete 'HKCU\Software\Wine\X11 Driver' /v UseTakeFocus /f >/dev/null 2>&1 || true
  fi
  wine reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d "${dpi}" /f >/dev/null
  wine reg add 'HKCU\Control Panel\Desktop' /v AppliedDPI /t REG_DWORD /d "${dpi}" /f >/dev/null
  wine reg add 'HKCU\Control Panel\Desktop' /v Win8DpiScaling /t REG_DWORD /d 1 /f >/dev/null
  wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes' /v 'MS Shell Dlg' /t REG_SZ /d "${ui_font}" /f >/dev/null
  wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes' /v 'MS Shell Dlg 2' /t REG_SZ /d "${ui_font}" /f >/dev/null

  set_logfont MenuFont 08000000
  set_logfont MessageFont 08000000
  set_logfont StatusFont 08000000
  set_logfont IconFont 08000000
  set_logfont SmCaptionFont 08000000
  set_logfont CaptionFont 0a000000
}

install_emeditor() {
  local archive programs_dir
  archive="$(resolve_archive)"
  programs_dir="${prefix}/drive_c/users/${wine_user}/AppData/Local/Programs"

  mkdir -p "${programs_dir}"
  rm -rf "${programs_dir}/EmEditor"
  bsdtar -xf "${archive}" -C "${programs_dir}"
}

font_file_sources() {
  if [[ -n "${EMEDITOR_WINE_FONTS_DIR:-}" ]]; then
    tr ':' '\n' <<<"${EMEDITOR_WINE_FONTS_DIR}"
  fi

  printf '%s\n' \
    "${HOME}/.wine-emeditor-fonts" \
    "${HOME}/.wine/drive_c/windows/Fonts" \
    "${HOME}/.local/share/fonts" \
    "/usr/share/fonts"
}

copy_optional_font() {
  local filename="$1"
  local source found

  while IFS= read -r source; do
    [[ -d "${source}" ]] || continue
    found="$(find "${source}" -iname "${filename}" -type f -print -quit 2>/dev/null || true)"
    if [[ -n "${found}" ]]; then
      install -Dm644 "${found}" "${prefix}/drive_c/windows/Fonts/${filename}"
      return 0
    fi
  done < <(font_file_sources)

  return 1
}

register_font_if_present() {
  local filename="$1"
  local name="$2"

  if [[ -f "${prefix}/drive_c/windows/Fonts/${filename}" ]]; then
    wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts' \
      /v "${name}" /t REG_SZ /d "${filename}" /f >/dev/null
  fi
}

import_optional_fonts() {
  local font

  mkdir -p "${prefix}/drive_c/windows/Fonts"

  for font in \
    segmdl2.ttf \
    SegoeIcons.ttf \
    segoeui.ttf \
    segoeuib.ttf \
    segoeuii.ttf \
    segoeuil.ttf \
    segoeuisl.ttf \
    segoeuiz.ttf \
    seguiemj.ttf \
    seguili.ttf \
    seguisb.ttf \
    seguisbi.ttf \
    seguisli.ttf \
    seguisym.ttf \
    webdings.ttf \
    msyh.ttc \
    msyhbd.ttc \
    msyhl.ttc; do
    [[ -f "${prefix}/drive_c/windows/Fonts/${font}" ]] || copy_optional_font "${font}" || true
  done

  register_font_if_present segmdl2.ttf 'Segoe MDL2 Assets (TrueType)'
  register_font_if_present SegoeIcons.ttf 'Segoe Fluent Icons (TrueType)'
  register_font_if_present segoeui.ttf 'Segoe UI (TrueType)'
  register_font_if_present segoeuib.ttf 'Segoe UI Bold (TrueType)'
  register_font_if_present segoeuii.ttf 'Segoe UI Italic (TrueType)'
  register_font_if_present segoeuil.ttf 'Segoe UI Light (TrueType)'
  register_font_if_present segoeuisl.ttf 'Segoe UI Semilight (TrueType)'
  register_font_if_present segoeuiz.ttf 'Segoe UI Bold Italic (TrueType)'
  register_font_if_present seguiemj.ttf 'Segoe UI Emoji (TrueType)'
  register_font_if_present seguili.ttf 'Segoe UI Light Italic (TrueType)'
  register_font_if_present seguisb.ttf 'Segoe UI Semibold (TrueType)'
  register_font_if_present seguisbi.ttf 'Segoe UI Semibold Italic (TrueType)'
  register_font_if_present seguisli.ttf 'Segoe UI Semilight Italic (TrueType)'
  register_font_if_present seguisym.ttf 'Segoe UI Symbol (TrueType)'
  register_font_if_present webdings.ttf 'Webdings (TrueType)'
  register_font_if_present msyh.ttc 'Microsoft YaHei UI (TrueType)'
  register_font_if_present msyhbd.ttc 'Microsoft YaHei UI Bold (TrueType)'
  register_font_if_present msyhl.ttc 'Microsoft YaHei UI Light (TrueType)'

  if [[ -z "${EMEDITOR_WINE_UI_FONT:-}" && -f "${prefix}/drive_c/windows/Fonts/msyh.ttc" ]]; then
    ui_font="Microsoft YaHei UI"
  fi
}

sync_desktop_entry() {
  local data_home desktop_dir desktop exec_line

  data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
  desktop_dir="${data_home}/applications/wine/Programs"
  desktop="${desktop_dir}/EmEditor.desktop"
  exec_line="${desktop_exec}"
  exec_line="${exec_line//\\/\\\\}"
  exec_line="${exec_line//\"/\\\"}"

  if [[ "${exec_line}" == *[[:space:]]* ]]; then
    exec_line="\"${exec_line}\""
  fi

  mkdir -p "${desktop_dir}"
  cat >"${desktop}" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=EmEditor
Comment=Launch EmEditor with the emeditor-wine wrapper
Exec=${exec_line} %F
Icon=emeditor-wine
Terminal=false
StartupNotify=true
StartupWMClass=emeditor.exe
Categories=Utility;TextEditor;Development;
MimeType=text/plain;
Keywords=text;editor;emeditor;wine;
EOF

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${data_home}/applications" >/dev/null 2>&1 || true
  fi
}

stop_disabled_tray_icon() {
  [[ "${tray_icon}" == "0" ]] || return 0
  wine taskkill /f /im emedtray.exe >/dev/null 2>&1 || true
}

run_emeditor() {
  local status=0

  if [[ "${refresh_mode}" == "desktop" ]]; then
    wine explorer "/desktop=EmEditor,$(pick_desktop_size)" "$(winepath -w "${app}")" "${args[@]}" || status=$?
  else
    wine "${app}" "${args[@]}" || status=$?
  fi

  stop_disabled_tray_icon
  return "${status}"
}

validate_options
export WINEPREFIX="${prefix}"
export LANG="${lang}"
export LC_ALL="${lang}"
export LANGUAGE="${EMEDITOR_WINE_LANGUAGE:-zh_CN:en_US}"

sync_desktop_entry
import_optional_fonts

dpi="$(pick_dpi)"
configure_prefix "${dpi}"
stop_disabled_tray_icon

if [[ ! -f "${app}" ]]; then
  install_emeditor
  configure_prefix "${dpi}"
  stop_disabled_tray_icon
  sync_desktop_entry
fi

args=()
for arg in "$@"; do
  if [[ -e "${arg}" ]]; then
    args+=("$(winepath -w "${arg}")")
  else
    args+=("${arg}")
  fi
done

run_emeditor
