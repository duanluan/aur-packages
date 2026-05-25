# wuyou-toolkit-bin

`wuyou-toolkit-bin` packages the prebuilt Linux release of
[wuyou-toolkit](https://github.com/duanluan/wuyou-toolkit-releases) for Arch Linux.

wuyou-toolkit is a cross-platform desktop toolbox built with Tauri.

## Install

With `paru`:

```bash
paru -S wuyou-toolkit-bin
```

With `yay`:

```bash
yay -S wuyou-toolkit-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/wuyou-toolkit-bin.git
cd wuyou-toolkit-bin
makepkg -si
```

## Launch

Start it from your application menu, or run:

```bash
wuyou-toolkit
```

## Notes

- The package repackages the upstream amd64 `.deb` release for Arch Linux.
- Runtime dependencies currently match the upstream Debian package metadata.
