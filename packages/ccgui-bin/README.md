# ccgui-bin

`ccgui-bin` packages the official x86_64 AppImage release of
[ccgui](https://github.com/zhukunpenglinyutong/desktop-cc-gui) for Arch Linux.

ccgui is a desktop client for Claude Code, Codex, Gemini, and Opencode.

## Install

With `paru`:

```bash
paru -S ccgui-bin
```

With `yay`:

```bash
yay -S ccgui-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/ccgui-bin.git
cd ccgui-bin
makepkg -si
```

## Launch

Start it from your application menu, or run:

```bash
ccgui
```

## Notes

- The package extracts the upstream binaries under `/opt/ccgui` and uses the
  system WebKitGTK and GStreamer runtime. This avoids ABI mismatches between
  the AppImage media libraries and Arch Linux GStreamer plugins.
- The `cc-gui` command is provided as a compatibility alias.
- The download page links to the upstream `desktop-cc-gui` release assets.
