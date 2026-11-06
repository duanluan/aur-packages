# uu-remote-linux-bin

`uu-remote-linux-bin` packages the official prebuilt Linux release of [uu-remote-linux](https://github.com/VallierDev/uu-remote-linux) for Arch Linux.

uu-remote-linux is an unofficial, open source (GPL-3.0-or-later) Linux host for NetEase UU Remote: after signing in with your UU Remote account, this Linux machine appears in the official Mac / Windows / mobile clients like a Windows host. It also ships an experimental Linux viewer (`uuremote-viewer`). Not affiliated with NetEase.

## Install

With `paru`:

```bash
paru -S uu-remote-linux-bin
```

With `yay`:

```bash
yay -S uu-remote-linux-bin
```

Manual install from this repository:

```bash
cd packages/uu-remote-linux-bin
makepkg -si
```

## Usage

Sign in from the graphical desktop (scan the QR code with the UU Remote app):

```bash
uuremote-server login
```

Run as a user service started with the graphical session:

```bash
systemctl --user daemon-reload
systemctl --user enable --now uuremote-native.service
journalctl --user -u uuremote-native.service -f
```

On Wayland, grant your user access to `/dev/uinput` (a udev rule is included in the package) so the host can inject input through kernel-level virtual keyboard/mouse:

```bash
sudo udevadm control --reload && sudo udevadm trigger --name-match=uinput
```

Desktop entries are installed for the host window (scan/assist) and the viewer.

## Notes

- The package name carries the `-bin` suffix because upstream is open source while this package ships its official prebuilt release artifacts.
- Binaries install to `/usr/bin`, the Wayland/portal capture plugins (`libuu-wayland.so`, `libuu-portal.so`) to `/usr/lib/uu-remote-linux/`.
- The user service is named `uuremote-native.service` on purpose: `uuremote-server show` and the desktop entry manage exactly this unit name.
- `uu-virtual-desktop` (Xvfb virtual desktop for monitorless hosts) is included; see `/usr/share/doc/uu-remote-linux-bin/virtual-display.conf.example`.
- Conflicts with `uu-remote-bin` and `uu-remote-linux`, which package the same upstream project; unlike `uu-remote-bin` this package also ships `uuremote-viewer`, the capture plugins and the desktop entries.
- FFmpeg with libx264 is required for desktop video. Desktop support matrix, headless setup and all options are documented in the [upstream README](https://github.com/VallierDev/uu-remote-linux#readme).
