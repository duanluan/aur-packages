# aur-packages

User-facing notes for the AUR packages maintained in this repository.

## Available Packages

- `rebased-bin`: A standalone Git client based on the IntelliJ platform
- `keyviz-zh-bin`: The Chinese-localized Keyviz package with Linux fixes

## Install

With `paru`:

```bash
paru -S rebased-bin
paru -S keyviz-zh-bin
```

With `yay`:

```bash
yay -S rebased-bin
yay -S keyviz-zh-bin
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
