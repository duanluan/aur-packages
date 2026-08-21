# wuyou-docs

`wuyou-docs` packages the prebuilt Linux release of
[Wuyou Docs](https://github.com/duanluan/wuyou-docs-releases) for Arch Linux.

Wuyou Docs is a local-first desktop document workspace built with Tauri.

## Install

With `paru`:

```bash
paru -S wuyou-docs
```

With `yay`:

```bash
yay -S wuyou-docs
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/wuyou-docs.git
cd wuyou-docs
makepkg -si
```

## Launch

Start it from your application menu, or run:

```bash
wuyou-docs
```

## Notes

- The package repackages the upstream amd64 `.deb` release for Arch Linux.
- Runtime dependencies currently match the upstream Debian package metadata.
