# Arch / AUR 打包规则摘录

记录 Arch 官方打包规则里与本仓库直接相关的条文，尤其是 `-bin` 后缀（prebuilt binary suffix，预编译二进制包的命名后缀）的命名规则。新包命名前先看这份文档。

规则来源（英文原文 + 通俗解释）：

- [AUR submission guidelines](https://wiki.archlinux.org/title/AUR_submission_guidelines)（AUR 提交指南）
- [Nonfree applications package guidelines](https://wiki.archlinux.org/title/Developer-manual:package-guidelines/non-free)（非自由软件打包指南）

## 1. `-bin` 后缀怎么用

AUR submission guidelines 原文：

> Packages that use **prebuilt** deliverables, **when the sources are available**, must use the `-bin` suffix.
> If you are packaging a non-free software, see also Nonfree applications package guidelines regarding usage of `-bin` suffix.

通俗解释：如果软件有源码可以本地编译，但你打的包是直接用官方预编译产物（prebuilt deliverable，官方做好的二进制文件），那包名必须加 `-bin`，用来和"从源码编译"的包区分开。

Nonfree applications package guidelines 原文（接上文，专指闭源软件）：

> For non-free software, **if the sources are not available, the `-bin` suffix should not be used**.
> Existence of `-bin` suffixed package in the AUR means that there is the potential to have a corresponding package without `-bin` in the AUR or in Official Repositories.

通俗解释：反过来，如果软件本身就是闭源的（non-free，非自由软件），根本没有源码可编译，那就不该加 `-bin`。`-bin` 存在的意义是"预留出不带 `-bin` 的源码包的位置"；没有源码包的可能，加 `-bin` 就是多余的。

### 本仓库的结论

| 软件情况 | 包名 | 例子（本仓库） |
| --- | --- | --- |
| 闭源、只有二进制 | 不带 `-bin` | `mastergo`、`zcode`、`reeden`、`tessoa`、`apifox` |
| 开源、从源码编译 | 不带后缀 | `keyviz-zh` |
| 开源、但包直接用官方预编译产物 | 加 `-bin` | `so-novel-bin`、`codeg-bin` |
| VCS（git 等）源码包 | 加 `-git` 等 | 暂无 |

历史包袱：早期部分闭源包取了 `xxx-bin` 名字（如 `mastergo-desktop-bin`、`zcode-desktop-bin`），后来按上述规则改名，旧名字保留为 transitional package（过渡包，升级时自动拉新包并提示改名），迁移脚本是 `scripts/publish-package-renames.sh`。

## 2. 不要建重复包

AUR submission guidelines 原文：

> **Check the AUR** if the package **already exists**. If it is currently maintained, changes can be submitted in a comment for the maintainer's attention. If it is unmaintained or the maintainer is unresponsive, the package can be adopted and updated as required. Do not create duplicate packages.

通俗解释：提交前先搜 AUR。同名包已存在且有人维护：改进意见发到该包的评论区；没人维护或维护者长期不回应：可以申请领养（adopt）。原则是不要发功能重复的包。

灰色地带：同一个闭源软件，别人发了 `xxx-bin`（比如从 Flatpak 解包），我们想发不带 `-bin` 的（比如从 AppImage 打包）。名字不同、打包方式不同，不算严格意义的重复包，且命名上按第 1 条规则我们更合规，但 TU（Trusted User，AUR 管理员）有裁量权。这种情况建议：

1. 打包质量拉开差距（构建依赖更轻、校验和锁死、更新及时）；
2. PKGBUILD 里写注释说明命名依据（引用本页第 1 条）；
3. 加 `conflicts`/`provides`（冲突/提供声明），让用户能平滑替换旧包；
4. 顺带在对方包的评论区留言，建议改名或参考新打包方式。

## 3. 其他常用条文

- 包名全小写（lowercase），不要含大写字母。
- 不要把版本号写进包名（version goes in `pkgver`，版本号字段）。
- 只支持非 x86_64 架构的包不允许提交到 AUR；x86_64 + aarch64 双架构没问题。
- `PKGBUILD` 顶部要有 Maintainer（维护者）注释行。
- 提交的包要有普遍用途，不是只有自己用的极特殊脚本。

## 4. 参考：本仓库包内字段约定

- 闭源软件 `license`（许可证字段）写 `LicenseRef-Proprietary` 或 `NOASSERTION`。
- `options=('!strip')`：预编译二进制不要 strip（strip 指剥离调试符号），避免破坏官方产物。
- 二进制包装到 `/opt/<包名>/`，`/usr/bin` 下放启动脚本或软链接。

## 相关命令

```bash
# 提交前搜 AUR 是否已有同名/同类包
curl -s 'https://aur.archlinux.org/rpc/v5/search/<关键词>?by=name' | jq -r '.results[].Name'

# 查包详情（版本、维护者、更新时间）
curl -s 'https://aur.archlinux.org/rpc/v5/info?arg[]=<包名>' | jq '.results[0]'
```
