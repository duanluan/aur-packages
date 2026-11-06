# coze

扣子（Coze）桌面端，从官方 macOS 版 dmg 转换打包。上游（字节跳动）目前只发布 Windows 和 macOS 桌面版（其更新服务的安装包清单里没有 linux 条目），本包把官方 mac 版的 Electron 应用取出来，用发行版的 electron39 运行。

## 转换做法

- 官方 dmg 是标准 Electron 打包：`app.asar` + Electron Framework（39.2.7）。asar 里的 JS 和全部原生模块（koffi、tree-sitter-bash/batch/powershell）都自带 linux-x64 预编译，跨平台部分无需改动。
- `prepare-app.mjs` 在构建时做三件事：
  1. 解出 `app.asar` 为 `app/` 目录（7z 不认 asar 格式，脚本自己解析头）；
  2. 给 `main/main.js` 打补丁：`process.resourcesPath` 支持环境变量覆盖（系统 electron 下它指向 electron 自己的 resources），并把只发 mac/win 安装包的内建更新服务在 Linux 上短路；
  3. 在 `main/bootstrap.js` 入口给 `ahaLog` / `ahaReporter` / `ahaPerf` / `ahaDeviceService` 注入空实现——上游用的是字节定制 Electron（@aha-kit/electron），官方 Electron 没有这些扩展，不桩掉会直接崩。
- 启动脚本设置 `COZE_DESKTOP_DEV_SHELL=true`（上游留的打包布局开关）和 `COZE_DESKTOP_RESOURCES_PATH`，缺前者会把渲染目录解析成 `app/app/renderer` 而白屏报 Not Found。
- `coze-daemon`、`coze-drive` 两个小助手是 Mach-O mac 二进制，不打包；应用运行时会按平台自行安装。

## 已知限制

- 内建自动更新被禁用（上游更新源只发 mac/win 安装包），更新走 AUR。
- 只在 x86_64 + Xvfb 冒烟到登录页（欢迎页渲染正常），登录后功能未逐项验证。
- aarch64 没做（asar 理论上通用，但没验证，dmg 里另有 arm64 版可换）。

## 版本跟踪

`update.sh` 查上游更新服务（`tron.jiyunhudong.com` 的 check_update2 接口）拿最新版本号和 CDN 地址（含 buildId 路径段），版本不变时跳过下载。
