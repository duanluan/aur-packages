# keyviz-zh

`keyviz-zh` packages the Chinese-localized Keyviz build for Arch Linux.

The package currently builds from the maintainer fork so Linux-specific fixes
can land before upstream merges them.

## Install

With `paru`:

```bash
paru -S keyviz-zh
```

With `yay`:

```bash
yay -S keyviz-zh
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/keyviz-zh.git
cd keyviz-zh
makepkg -si
```

## Launch

Start it from your application menu, or run:

```bash
keyviz
```

## Notes

- The desktop entry is shown as `Keyviz 汉化版`.
- Linux fixes are sourced from `https://github.com/duanluan/keyviz`.
