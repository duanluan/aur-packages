# rebased-bin

`rebased-bin` packages the prebuilt Linux release of
[Rebased](https://github.com/DetachHead/rebased) for Arch Linux.

Rebased is a standalone Git client built on the IntelliJ platform.

## Install

With `paru`:

```bash
paru -S rebased-bin
```

With `yay`:

```bash
yay -S rebased-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/rebased-bin.git
cd rebased-bin
makepkg -si
```

## Launch

Start it from your application menu, or run:

```bash
rebased
```

## Notes

- The package installs a desktop entry and application icon.
- Configuration files are initialized on first launch.
