# wuyou-toolkit

`wuyou-toolkit` packages the prebuilt Linux release of
[wuyou-toolkit](https://github.com/duanluan/wuyou-toolkit-releases) for Arch Linux.

wuyou-toolkit is a cross-platform desktop toolbox built with Tauri.

## Install

With `paru`:

```bash
paru -S wuyou-toolkit
```

With `yay`:

```bash
yay -S wuyou-toolkit
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/wuyou-toolkit.git
cd wuyou-toolkit
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
