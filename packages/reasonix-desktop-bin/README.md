# reasonix-desktop-bin

`reasonix-desktop-bin` repackages the prebuilt `.deb` release of
[Reasonix Desktop](https://github.com/esengine/DeepSeek-Reasonix) for Arch Linux.

Reasonix Desktop is a Wails-based desktop GUI for the Reasonix terminal-native
AI coding agent with DeepSeek API.

## Notes

- This package uses the official `.deb` release (native Go/Wails binary) with
  only two dependencies: `gtk3` and `webkit2gtk-4.1`.
- `deepseek-reasonix-desktop-bin` (AUR) at v1.7.0 uses a raw tarball approach
  with 24 Electron-related dependencies and produces a white screen.

## Install

With `paru`:

```bash
paru -S reasonix-desktop-bin
```

With `yay`:

```bash
yay -S reasonix-desktop-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/reasonix-desktop-bin.git
cd reasonix-desktop-bin
makepkg -si
```

## Launch

Start it from your application menu, or run:

```bash
reasonix-desktop
```

## Conflicts

This package conflicts with `reasonix-desktop`, `deepseek-reasonix-desktop`,
and `deepseek-reasonix-desktop-bin` — only one Reasonix Desktop package should
be installed at a time.
