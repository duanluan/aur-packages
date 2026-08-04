# android-dex-bin

`android-dex-bin` packages the official x86_64 Linux bundle of [Android DEX](https://github.com/Shrey113/Android-Dex) for Arch Linux.

Android DEX lets you use an Android device through a desktop-style interface over USB or Wi-Fi.

## Install

With `paru`:

```bash
paru -S android-dex-bin
```

With `yay`:

```bash
yay -S android-dex-bin
```

Manual install from this repository:

```bash
cd packages/android-dex-bin
makepkg -si
```

## Launch

Start it from your application menu, or run:

```bash
android-dex
```

## Notes

- The package installs the upstream Linux bundle under `/opt/android-dex`.
- The package provides the `android-dex` launcher and desktop entry.
- Upstream bundles ADB and scrcpy for device access.
- Enable Android USB debugging before connecting a device.
