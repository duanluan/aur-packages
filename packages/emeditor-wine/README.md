# emeditor-wine

EmEditor 26.1.1 running through a dedicated Wine prefix.

The AUR package downloads the launcher source from the tagged
`duanluan/emeditor-linux` release and downloads the official EmEditor MSI during
`makepkg`. The built local package keeps the MSI under
`/usr/share/emeditor-wine/`, so first launch does not need to download the
installer again.

The launcher installs EmEditor into `~/.wine-emeditor` on first run, disables
DirectWrite to avoid Wine startup crashes, applies high-DPI settings, and uses
an open-source CJK UI font by default.

If Windows UI fonts are already available on the host, the launcher can import them into the Wine prefix. Segoe UI fonts can improve Windows-specific glyph rendering, and `Microsoft YaHei UI` improves Simplified Chinese UI rendering. The package does not ship Microsoft fonts. The persistent trial notification indicator in EmEditor's status bar may still render as square glyphs under Wine.

Useful overrides:

```sh
EMEDITOR_WINEPREFIX="$HOME/.wine-emeditor-test" emeditor-wine
EMEDITOR_WINE_DPI=192 emeditor-wine
EMEDITOR_WINE_UI_FONT="Microsoft YaHei UI" emeditor-wine
EMEDITOR_WINE_FONTS_DIR="$HOME/win11-fonts" emeditor-wine
EMEDITOR_WINE_LANG=en_US.utf8 emeditor-wine
```
