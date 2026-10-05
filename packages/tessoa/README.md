# tessoa

[tessoa](https://tessoa.cn/)（GPU 加速文件管理器，同窗口分屏浏览、预览文件，支持布局保存、彩色标签与多种视图）的 AUR 包。软件闭源（免费版长期可用），按仓库规范用正式名、不带 `-bin` 后缀。

上游只提供固定 latest 地址 `https://download.tessoa.com/tessoa/latest/tessoa.tar.gz`，没有版本化链接，也没有公开版本接口。update.sh 先用响应 ETag（记录在 PKGBUILD 的 `# upstream etag:` 注释里）做低成本探测，ETag 变了才下载压缩包，从二进制内嵌字符串（形如 `tessoa 0.27.0`）读出版本号，更新 `pkgver`（版本号）、`sha256sums`（校验值）后用 `makepkg --printsrcinfo` 重新生成 `.SRCINFO`。

打包内容：

- 二进制装 `/usr/bin/tessoa`
- 桌面项装 `/usr/share/applications/tessoa.desktop`（上游 Exec 就是 `tessoa %F`，无需改写）
- 512×512 图标装进 hicolor 图标目录
- 第三方开源声明装 `/usr/share/licenses/tessoa/THIRD-PARTY-NOTICES.html`

上游 `install.sh` 是用户级（`~/.local`）安装脚本，包内不使用，装了本包后不要再跑它，否则两边会互相覆盖。

图形栈是 Vulkan（wgpu 渲染），X11/Wayland 相关库在运行时动态加载，所以 depends（依赖）里列出了 `vulkan-icd-loader`、`vulkan-driver` 和对应的 X11/Wayland 库。
