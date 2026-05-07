# aur-packages

User-facing notes for the AUR packages maintained in this repository.

## Available Packages

- `rebased-bin`: A standalone Git client based on the IntelliJ platform
- `keyviz-zh-bin`: The Chinese-localized Keyviz package with Linux fixes
- `wuyou-docs-bin`: The prebuilt Linux desktop release of Wuyou Docs

## Install

With `paru`:

```bash
paru -S rebased-bin
paru -S keyviz-zh-bin
paru -S wuyou-docs-bin
```

With `yay`:

```bash
yay -S rebased-bin
yay -S keyviz-zh-bin
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
- [wuyou-docs-bin](packages/wuyou-docs-bin/README.md)
