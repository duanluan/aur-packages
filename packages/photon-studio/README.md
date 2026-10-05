# photon-studio

`photon-studio` packages the official Linux x64 AppImage of [Photon Studio](https://tenzen.studio/photon/) for Arch Linux.

Photon Studio（Photon 照相工作室）是 Tenzen Studio 出品的免费桌面照片/图像编辑器，支持图层和原生 PSD（Photoshop 文件格式），可离线使用。闭源软件，仅官方二进制发布。

## Install

With `paru`:

```bash
paru -S photon-studio
```

With `yay`:

```bash
yay -S photon-studio
```

Manual install from this repository:

```bash
cd packages/photon-studio
makepkg -si
```

## Usage

从应用菜单启动 "Photon Studio"，或命令行运行：

```bash
photon-studio
```

## Notes

- 包名不带 `-bin`：Photon Studio 是闭源软件（没有源码可编译），按 [Arch 打包规则](../../docs/aur-packaging-rules.md) 不应加 `-bin` 后缀。
- 与 AUR 上第三方的 `photon-studio-bin`（从 Flatpak 解包）装的是同一个官方软件；本包声明了 `conflicts`/`provides`，安装时会自动替换它。
- 本包从官方 AppImage 解包，构建不需要 `flatpak`，下载文件的 sha256 校验和锁死在 PKGBUILD 里。
- 应用本体安装在 `/opt/photon-studio/`，启动器是 `/usr/bin/photon-studio`，桌面文件和图标装到标准位置。
