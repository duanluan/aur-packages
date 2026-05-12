# aur-packages

User-facing notes for the AUR packages maintained in this repository.

## Available Packages

- `rebased-bin`: A standalone Git client based on the IntelliJ platform
- `keyviz-zh-bin`: The Chinese-localized Keyviz package with Linux fixes
- `navicat17-premium-cs`: The Chinese Simplified Navicat Premium 17 AppImage package
- `wuyou-docs-bin`: The prebuilt Linux desktop release of Wuyou Docs

## Install

With `paru`:

```bash
paru -S rebased-bin
paru -S keyviz-zh-bin
paru -S navicat17-premium-cs
paru -S wuyou-docs-bin
```

With `yay`:

```bash
yay -S rebased-bin
yay -S keyviz-zh-bin
yay -S navicat17-premium-cs
yay -S wuyou-docs-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/rebased-bin.git
cd rebased-bin
makepkg -si
```

## Package Notes

- [rebased-bin](packages/rebased-bin/README.md)
- [keyviz-zh-bin](packages/keyviz-zh-bin/README.md)
- [navicat17-premium-cs](packages/navicat17-premium-cs/README.md)
- [wuyou-docs-bin](packages/wuyou-docs-bin/README.md)

## Auto Update

The GitHub Actions workflow `.github/workflows/aur-auto-update.yml` checks these
packages every 12 hours:

- `rebased-bin`
- `keyviz-zh-bin`
- `navicat17-premium-cs`
- `wuyou-docs-bin`

It regenerates package files, commits changes back to this repository, and then
publishes changed `PKGBUILD` and `.SRCINFO` files to AUR.

`pdmaas-pro-bin` is intentionally excluded because the upstream Pro package
requires a download code instead of a stable public source URL.
