# aur-packages

User-facing notes for the AUR packages maintained in this repository.

## Available Packages

- `rebased-bin`: A standalone Git client based on the IntelliJ platform
- `keyviz-zh`: The Chinese-localized Keyviz package with Linux fixes
- `navicat17-premium-cs`: The Chinese Simplified Navicat Premium 17 AppImage package
- `wuyou-docs`: The prebuilt Linux desktop release of Wuyou Docs
- `wuyou-toolkit`: The prebuilt Linux desktop release of wuyou-toolkit
- `mind-elixir`: The prebuilt Linux desktop release of Mind Elixir
- `ccgui-bin`: The prebuilt Linux desktop release of ccgui
- `codeg-bin`: Codeg multi-agent coding workspace repackaged from the official .deb release
- `codepilot-bin`: CodePilot desktop client repackaged from the official .deb release
- `gooeypi-bin`: GooeyPi desktop workspace repackaged from the official Arch release
- `codex-plus-plus`: Codex++ injection bridge for the ChatGPT desktop app
- `zcode`: ZCode desktop app repackaged from the official Linux release
- `mastergo`: MasterGo desktop app repackaged from the official macOS release
- `pilauncher-bin`: The prebuilt Linux desktop release of PiLauncher
- `pideck-bin`: The prebuilt Linux desktop release of PiDeck
- `minimax-hub`: MiniMax Hub desktop app repackaged from the official macOS release
- `reasonix-desktop-bin`: Reasonix desktop app repackaged from the official .deb release
- `pi-agent-desktop-bin`: Pi Agent desktop app repackaged from the official .deb release
- `reeden`: Reeden desktop app repackaged from the official .deb release
- `alexandria-bin`: Alexandria desktop app repackaged from the official .deb release
- `android-dex-bin`: Android DEX Linux bundle repackaged from the official release
- `so-novel-bin`: So Novel web content extraction and ebook export tool
- `emeditor-wine`: EmEditor running through a dedicated Wine prefix

## Install

With `paru`:

```bash
paru -S rebased-bin
paru -S keyviz-zh
paru -S navicat17-premium-cs
paru -S wuyou-docs
paru -S wuyou-toolkit
paru -S mind-elixir
paru -S ccgui-bin
paru -S codeg-bin
paru -S codepilot-bin
paru -S gooeypi-bin
paru -S codex-plus-plus
paru -S zcode
paru -S mastergo
paru -S pilauncher-bin
paru -S pideck-bin
paru -S minimax-hub
paru -S reasonix-desktop-bin
paru -S pi-agent-desktop-bin
paru -S reeden
paru -S alexandria-bin
paru -S android-dex-bin
paru -S so-novel-bin
paru -S emeditor-wine
```

With `yay`:

```bash
yay -S rebased-bin
yay -S keyviz-zh
yay -S navicat17-premium-cs
yay -S wuyou-docs
yay -S wuyou-toolkit
yay -S mind-elixir
yay -S ccgui-bin
yay -S codeg-bin
yay -S codepilot-bin
yay -S gooeypi-bin
yay -S codex-plus-plus
yay -S zcode
yay -S mastergo
yay -S pilauncher-bin
yay -S pideck-bin
yay -S minimax-hub
yay -S reasonix-desktop-bin
yay -S pi-agent-desktop-bin
yay -S reeden
yay -S alexandria-bin
yay -S android-dex-bin
yay -S so-novel-bin
yay -S emeditor-wine
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/rebased-bin.git
cd rebased-bin
makepkg -si
```

## Renamed Packages

The former package names remain available as transitional packages. Updating
an installed transitional package pulls in its replacement and prints the new
name:

- `keyviz-zh-bin` -> `keyviz-zh`
- `mastergo-desktop-bin` -> `mastergo`
- `minimax-hub-bin` -> `minimax-hub`
- `mind-elixir-bin` -> `mind-elixir`
- `reeden-bin` -> `reeden`
- `wuyou-docs-bin` -> `wuyou-docs`
- `wuyou-toolkit-bin` -> `wuyou-toolkit`
- `zcode-desktop-bin` -> `zcode`

Publish a rename migration once after committing the package files:

```bash
./scripts/publish-package-renames.sh
```

The script publishes all canonical packages before updating the transitional
package repositories.

## Package Notes

- [rebased-bin](packages/rebased-bin/README.md)
- [keyviz-zh](packages/keyviz-zh/README.md)
- [navicat17-premium-cs](packages/navicat17-premium-cs/README.md)
- [wuyou-docs](packages/wuyou-docs/README.md)
- [wuyou-toolkit](packages/wuyou-toolkit/README.md)
- [mind-elixir](packages/mind-elixir/README.md)
- [ccgui-bin](packages/ccgui-bin/README.md)
- [codeg-bin](packages/codeg-bin/README.md)
- [codepilot-bin](packages/codepilot-bin/README.md)
- [gooeypi-bin](packages/gooeypi-bin/README.md)
- [codex-plus-plus](packages/codex-plus-plus/README.md)
- [zcode](packages/zcode/README.md)
- [mastergo](packages/mastergo/README.md)
- [pilauncher-bin](packages/pilauncher-bin/README.md)
- [pideck-bin](packages/pideck-bin/README.md)
- [minimax-hub](packages/minimax-hub/README.md)
- [reasonix-desktop-bin](packages/reasonix-desktop-bin/README.md)
- [pi-agent-desktop-bin](packages/pi-agent-desktop-bin/README.md)
- [reeden](packages/reeden/README.md)
- [alexandria-bin](packages/alexandria-bin/README.md)
- [android-dex-bin](packages/android-dex-bin/README.md)
- [so-novel-bin](packages/so-novel-bin/README.md)
- [emeditor-wine](packages/emeditor-wine/README.md)

## Auto Update

The GitHub Actions workflow `.github/workflows/aur-auto-update.yml` checks
frequently updated packages daily:

- `rebased-bin`
- `rebased-zh-bin`
- `ccgui-bin`
- `codeg-bin`
- `codepilot-bin`
- `gooeypi-bin`
- `zcode`
- `minimax-hub`
- `reasonix-desktop-bin`
- `pi-agent-desktop-bin`
- `pilauncher-bin`
- `pideck-bin`

Less frequently updated packages stay on the weekly check:

- `keyviz-zh`
- `emeditor-wine`
- `navicat17-premium-cs`
- `wuyou-docs`
- `wuyou-toolkit`
- `mind-elixir`
- `mastergo`
- `reeden`
- `alexandria-bin`
- `android-dex-bin`
- `so-novel-bin`

It regenerates package files, commits changes back to this repository, and then
publishes changed AUR files to AUR.

`codex-plus-plus` is intentionally excluded because every upstream release needs
manual build and runtime verification before publishing.

`pdmaas-pro-bin` is intentionally excluded because the upstream Pro package
requires a download code instead of a stable public source URL.
