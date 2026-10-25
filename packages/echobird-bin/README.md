# echobird-bin

`echobird-bin` repackages the official Linux `.deb` release of
[EchoBird](https://github.com/edison7009/EchoBird) for Arch Linux on x86_64
and aarch64.

EchoBird is an open-source Tauri desktop hub for AI coding: manage ChatGPT,
Codex CLI and Claude Code accounts in one place, track quota, route requests
through multiple models with priority and automatic failover, install AI
coding tools, and deploy local LLMs.

## Install

With `paru`:

```bash
paru -S echobird-bin
```

With `yay`:

```bash
yay -S echobird-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/echobird-bin.git
cd echobird-bin
makepkg -si
```

## Usage

Start EchoBird from the application menu, or run:

```bash
echobird
```

## Notes

- This package uses the upstream `.deb` release and does not require FUSE.
- The tray icon needs `libayatana-appindicator`, which is installed as a hard
  dependency (the same way the upstream `.deb` declares it).
- On NVIDIA GPUs the WebKitGTK DMABUF renderer paints a fully transparent
  window, so `/usr/bin/echobird` is a wrapper that sets
  `WEBKIT_DISABLE_DMABUF_RENDERER=1` and runs the real binary
  `/usr/bin/echobird.bin`. Set the variable to `0` yourself to re-enable
  hardware acceleration on other GPUs.
- Application state lives under `~/.local/share/com.echobird.ai/`; account
  API keys are stored encrypted.
- The project is MIT licensed since v5.0.0 (v4.x and earlier were AGPL-3.0).
