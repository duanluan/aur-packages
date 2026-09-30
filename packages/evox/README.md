# evox

[EvoX](https://evomap.ai/zh/evox/beta)（EvoMap 出品的自进化蜂群智能体，beta 渠道）的 AUR 包。软件闭源，按仓库规范用正式名、不带 `-bin` 后缀。源为官方 Linux 发行清单 `https://res.evomap.ai/downloads/evox-linux/beta/manifest.json`。

## 打包方式

上游压缩包是"安装器分发包"而不是可直接运行的目录：二进制只从
`<agent-dir>/entitlement.json`（默认 `~/.evox/agent/`）读取与版本绑定的授权，不会在二进制旁边找。因此本包：

- 二进制、entitlement、签名扩展装在 `/usr/lib/evox/`
- `/usr/bin/evox` 是启动脚本，首次运行（或包升级后）把 entitlement 和
  `extensions/*.so + .sig` 同步到 `~/.evox/agent/`，然后执行真正的二进制
- 同步以 `~/.evox/agent/.evox-stamp` 记录的版本为基准，只增删本包管理的
  `libevox_ext_*` 文件，不影响用户用 `evox ext install` 装的扩展
- 支持 `EVOX_CODING_AGENT_DIR` / `EVOX_AGENT_DIR` 覆盖 agent 目录（含 `~` 前缀）

注意：entitlement 与发行版本绑定，不要同时使用官方 `install.sh` 安装的
`~/.evox/bin/evox`（两者会互相覆盖 `~/.evox/agent` 里的 entitlement）。

## 更新流程

上游发新版后（update.sh 会读 manifest 自动完成 1、2 步）：

1. `./update.sh` 更新 `PKGBUILD` 与 `.SRCINFO`
2. `makepkg --printsrcinfo > .SRCINFO`（update.sh 已内置）
3. `./sync-aur.sh` 推送到 AUR
