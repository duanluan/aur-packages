# aur-packages

User-facing notes for the AUR packages maintained in this repository.

## Packages

- [rebased-bin](packages/rebased-bin/README.md): A standalone Git client based on the IntelliJ platform
- [rebased-zh-bin](packages/rebased-zh-bin/README.md): Chinese language pack for Rebased
- [keyviz-zh](packages/keyviz-zh/README.md): Chinese-localized Keyviz package with Linux fixes
- [navicat17-premium-cs](packages/navicat17-premium-cs/README.md): Chinese Simplified Navicat Premium 17 AppImage package
- [wuyou-docs](packages/wuyou-docs/README.md): Prebuilt Linux desktop release of Wuyou Docs
- [wuyou-toolkit](packages/wuyou-toolkit/README.md): Prebuilt Linux desktop release of wuyou-toolkit
- [mind-elixir](packages/mind-elixir/README.md): Prebuilt Linux desktop release of Mind Elixir
- [ccgui-bin](packages/ccgui-bin/README.md): Prebuilt Linux desktop release of ccgui
- [codeg-bin](packages/codeg-bin/README.md): Codeg multi-agent coding workspace
- [codepilot-bin](packages/codepilot-bin/README.md): CodePilot desktop client
- [gooeypi-bin](packages/gooeypi-bin/README.md): GooeyPi desktop workspace
- [codex-plus-plus](packages/codex-plus-plus/README.md): Codex++ injection bridge for the ChatGPT desktop app
- [zcode](packages/zcode/README.md): ZCode desktop app
- [mastergo](packages/mastergo/README.md): MasterGo desktop app
- [pilauncher-bin](packages/pilauncher-bin/README.md): Prebuilt Linux desktop release of PiLauncher
- [pideck-bin](packages/pideck-bin/README.md): Prebuilt Linux desktop release of PiDeck
- [minimax-hub](packages/minimax-hub/README.md): MiniMax Hub desktop app
- [reasonix-desktop-bin](packages/reasonix-desktop-bin/README.md): Reasonix desktop app
- [pi-agent-desktop-bin](packages/pi-agent-desktop-bin/README.md): Pi Agent desktop app
- [reeden](packages/reeden/README.md): Reeden desktop app
- [alexandria-bin](packages/alexandria-bin/README.md): Alexandria desktop app
- [android-dex-bin](packages/android-dex-bin/README.md): Android DEX Linux bundle
- [apifox](packages/apifox/README.md): Apifox API documentation, debugging, mocking, and automated testing tool
- [so-novel-bin](packages/so-novel-bin/README.md): So Novel web content extraction and ebook export tool
- [emeditor-wine](packages/emeditor-wine/README.md): EmEditor running through a dedicated Wine prefix
- [opensquilla](packages/opensquilla/README.md): OpenSquilla desktop app

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
- `opensquilla`
- `apifox`

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
