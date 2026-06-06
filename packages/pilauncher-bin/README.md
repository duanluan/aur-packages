# pilauncher-bin

`pilauncher-bin` packages the prebuilt Linux release of
[PiLauncher](https://github.com/MrShellad/pilauncher) for Arch Linux.

PiLauncher is a modern gamepad-friendly Minecraft launcher built with Tauri.

## Install

With `paru`:

```bash
paru -S pilauncher-bin
```

With `yay`:

```bash
yay -S pilauncher-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/pilauncher-bin.git
cd pilauncher-bin
makepkg -si
```

## Launch

Start it from your application menu, or run:

```bash
pilauncher
```

## Notes

- The package extracts the upstream amd64 AppImage and runs it against Arch's
  system GTK/WebKit stack for better desktop compatibility.
- PiLauncher is an independent third-party Minecraft launcher and does not distribute Minecraft.
