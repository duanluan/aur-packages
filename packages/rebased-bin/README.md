# rebased-bin

`rebased-bin` packages the official x86_64 AppImage release of
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

- The package installs the upstream AppImage under `/opt/rebased`.
- The launcher runs the AppImage directly to preserve upstream Linux behavior.
- Configuration files are initialized on first launch.
