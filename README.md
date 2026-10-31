# aur-packages

User-facing notes for the AUR packages maintained in this repository.

## Packages

| Name | Former Names | Description | Daily | Weekly |
| --- | --- | --- | :-: | :-: |
| [agents-anywhere](packages/agents-anywhere/README.md) | | Agents Anywhere cross-device AI agent workbench (source build of desktop-workbench) | ✓ | |
| [alexandria-bin](packages/alexandria-bin/README.md) | | Alexandria desktop app | | ✓ |
| [android-dex-bin](packages/android-dex-bin/README.md) | | Android DEX Linux bundle | | ✓ |
| [apifox](packages/apifox/README.md) | | Apifox API documentation, debugging, mocking, and automated testing tool | ✓ | |
| [arch-cleaner-bin](packages/arch-cleaner-bin/README.md) | | Interactive TUI cleanup tool for Arch Linux (pacman cache, journal, user/AI-agent caches, large and duplicate files) | | |
| [ccgui-bin](packages/ccgui-bin/README.md) | | Prebuilt Linux desktop release of ccgui | ✓ | |
| [codeg-bin](packages/codeg-bin/README.md) | | Codeg multi-agent coding workspace | ✓ | |
| [codeg-server-bin](packages/codeg-server-bin/README.md) | | Standalone server of Codeg | ✓ | |
| [codepilot-bin](packages/codepilot-bin/README.md) | | CodePilot desktop client | ✓ | |
| [codex-plus-plus](packages/codex-plus-plus/README.md) | | Codex++ injection bridge for the ChatGPT desktop app | | |
| [echobird-bin](packages/echobird-bin/README.md) | | Prebuilt Linux desktop release of EchoBird | ✓ | |
| [edithere-bin](packages/edithere-bin/README.md) | | Screenshot annotation and visual feedback tool | | ✓ |
| [emeditor-wine](packages/emeditor-wine/README.md) | | EmEditor running through a dedicated Wine prefix | | ✓ |
| [evox](packages/evox/README.md) | | EvoMap EvoX self-evolving swarm coding agent (beta channel) | ✓ | |
| [gooeypi-bin](packages/gooeypi-bin/README.md) | | GooeyPi desktop workspace | ✓ | |
| [hifox-cli](packages/hifox-cli/README.md) | | HiFox CLI terminal client for the HiFox human and AI agent collaboration platform | | |
| [keyviz-zh](packages/keyviz-zh/README.md) | ~~keyviz-zh-bin~~ | Chinese-localized Keyviz package with Linux fixes | | ✓ |
| [ldtk-git](packages/ldtk-git/README.md) | | Modern and efficient 2D level editor with a strong focus on user-friendliness (git master) | | ✓ |
| [mastergo](packages/mastergo/README.md) | ~~mastergo-desktop-bin~~ | MasterGo desktop app | | ✓ |
| [mimo-desktop](packages/mimo-desktop/README.md) | | Xiaomi MiMo desktop app | | ✓ |
| [mind-elixir](packages/mind-elixir/README.md) | ~~mind-elixir-bin~~ | Prebuilt Linux desktop release of Mind Elixir | | ✓ |
| [minimax-design](packages/minimax-design/README.md) | ~~minimax-hub~~, ~~minimax-hub-bin~~ | MiniMax Design desktop app (formerly MiniMax Hub) | ✓ | |
| [navicat17-premium-cs](packages/navicat17-premium-cs/README.md) | | Chinese Simplified Navicat Premium 17 AppImage package | | ✓ |
| [opensquilla](packages/opensquilla/README.md) | | OpenSquilla desktop app | | ✓ |
| [pdmaas-pro-bin](packages/pdmaas-pro-bin/README.md) | | Enterprise data modeling platform (prebuilt binary) | | |
| [photon-studio](packages/photon-studio/README.md) | | Photon Studio desktop photo and image editor | ✓ | |
| [pi-agent-desktop-bin](packages/pi-agent-desktop-bin/README.md) | | Pi Agent desktop app | ✓ | |
| [pideck-bin](packages/pideck-bin/README.md) | | Prebuilt Linux desktop release of PiDeck | ✓ | |
| [pilauncher-bin](packages/pilauncher-bin/README.md) | | Prebuilt Linux desktop release of PiLauncher | | ✓ |
| [qoder-cn](packages/qoder-cn/README.md) | | Qoder CN desktop app repackaged from the official Linux deb | ✓ | |
| [reasonix-desktop-bin](packages/reasonix-desktop-bin/README.md) | | Reasonix desktop app | ✓ | |
| [rebased-bin](packages/rebased-bin/README.md) | | A standalone Git client based on the IntelliJ platform | ✓ | |
| [rebased-zh-bin](packages/rebased-zh-bin/README.md) | | Chinese language pack for Rebased | ✓ | |
| [reeden](packages/reeden/README.md) | ~~reeden-bin~~ | Reeden desktop app | | ✓ |
| [so-novel-bin](packages/so-novel-bin/README.md) | | So Novel web content extraction and ebook export tool | | ✓ |
| [strata-terminal-bin](packages/strata-terminal-bin/README.md) | | Strata Terminal CLI to run Qwen3.8-Flash-Next / DeepSeek V4.1-Flash locally (prebuilt) | ✓ | |
| [tessoa](packages/tessoa/README.md) | | GPU-accelerated file manager with split panes, layouts, tags and multiple views | ✓ | |
| [wechat-xwayland](packages/wechat-xwayland/README.md) | | Launch WeChat through XWayland with a KDE window-activation command | | |
| [workbuddy-international](packages/workbuddy-international/README.md) | | WorkBuddy AI international edition (unofficial Linux port from the macOS build) | ✓ | |
| [wuyou-docs](packages/wuyou-docs/README.md) | ~~wuyou-docs-bin~~ | Prebuilt Linux desktop release of Wuyou Docs | | ✓ |
| [wuyou-toolkit](packages/wuyou-toolkit/README.md) | ~~wuyou-toolkit-bin~~ | Prebuilt Linux desktop release of wuyou-toolkit | | ✓ |
| [zcode](packages/zcode/README.md) | ~~zcode-desktop-bin~~ | ZCode desktop app | ✓ | |
| [zcode-pro](packages/zcode-pro/README.md) | | UI enhancement launcher for the ZCode desktop app (custom project aliases) | | |

Former names remain available on the AUR as transitional packages:
updating an installed transitional package automatically replaces it with
the current one.

Daily entries are checked once a day and weekly entries every Monday;
packages with neither mark are updated manually as needed. Two of them are
excluded from auto updates on purpose: every `codex-plus-plus` release
requires manual build and runtime verification before publishing, and
`pdmaas-pro-bin` has no stable public source URL because upstream requires
a download code.
