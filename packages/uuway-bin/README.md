# uuway-bin

`uuway-bin` repacks the official prebuilt Arch release of [UUWay](https://github.com/GaryOAO/UUWay) for the AUR.

UUWay runs the official Windows NetEase UU Remote host under a pinned Wine 11 on Linux, with native Linux components for capture, input and display management (GNOME Wayland, NVIDIA NVENC or AMD VA-API). The UU program files stay unmodified; the project is open source (AGPL-3.0-only) and not affiliated with NetEase.

## Install

With `paru`:

```bash
paru -S uuway-bin
```

With `yay`:

```bash
yay -S uuway-bin
```

Manual install from this repository:

```bash
cd packages/uuway-bin
makepkg -si
```

## Usage

Run the setup wizard as your regular user in a GNOME Wayland session:

```bash
uuway setup
```

The wizard finds the UU Windows installer in your Downloads folder (or downloads it from the official UU API), signs you in, verifies the encoding backend and configures the user services. Then open **UUWay 控制台** (UUWay Console) from the application menu.

Common commands:

```bash
uuway doctor                  # check environment and services
uuway refresh --restart-display
uuway uninstall               # clean removal (run before uninstalling the package)
```

## Notes

- The package name carries the `-bin` suffix because upstream is open source while this package repacks its official prebuilt Arch release artifact.
- Files install verbatim from upstream's `uuway-<version>-1-x86_64.pkg.tar.zst`, including the `70-uurb-native-input.rules` udev rule and the desktop entry.
- The built-in self-updater is switched off in this package (`"ota": false` in `package-info.json`, upstream's own opt-in flag): it detects the installed version via `pacman -Q uuway` and installs upstream's `uuway-*.pkg.tar.zst`, which cannot work under the `uuway-bin` package name. Update through your AUR helper (`paru -Suu`) instead of `uuway update`.
- Conflicts with `uuway` and `uuway-git`.
- Arch support upstream is experimental; the reference environment is GNOME Wayland with NVIDIA NVENC or AMD VA-API. Desktop requirements, supported features and Wine pinning are documented in the [upstream README](https://github.com/GaryOAO/UUWay#readme).
