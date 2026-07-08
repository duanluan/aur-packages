# navicat17-premium-cs

`navicat17-premium-cs` packages the official Chinese Simplified Linux AppImage
builds of [Navicat Premium](https://www.navicat.com.cn/products/navicat-premium)
for Arch Linux.

## Install

With `paru`:

```bash
paru -S navicat17-premium-cs
```

With `yay`:

```bash
yay -S navicat17-premium-cs
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/navicat17-premium-cs.git
cd navicat17-premium-cs
makepkg -si
```

## Launch

Start it from your application menu, or run:

```bash
navicat
```

## Notes

- The package repackages the upstream x86_64 and aarch64 AppImage builds from the official
  [download page](https://www.navicat.com.cn/download/navicat-premium).
- Linux package versions should track the latest entry in the official
  [release notes](https://www.navicat.com.cn/products/navicat-premium-release-note).
- The public upstream download is the 14-day trial build; licensed users can
  activate it after installation.
