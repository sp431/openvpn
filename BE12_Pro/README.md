# Tenda BE12 Pro — OpenVPN 安装说明

本目录为 **Tenda BE12 Pro** 的 OpenVPN 安装支持。脚本复用仓库内跨内核通用的 LuCI apk 与 src。

## 设备信息（实测 2026-09-22）

| 项目 | 值 |
|---|---|
| 型号 | Tenda BE12 Pro（`tenda,be12-pro`） |
| 系统 | OpenWrt SNAPSHOT r34613（FanchmWrt） |
| 内核 | 6.18.31 aarch64 |
| 架构 | mediatek/filogic / aarch64_cortex-a53 |
| 包管理器 | apk |
| 内存 / overlay | 512 MB / **65 MB** |
| 网络 | br-lan 192.168.1.1 / phy0.1-sta0 192.168.254.60 |

## 安装

把**整个仓库**放到设备（脚本复用 `rudy-TR3000/packages` 与 `rudy-TR3000/src`）：

```sh
cd /tmp/openvpn
sh BE12_Pro/scripts/install-openvpn.sh
```

安装后页面：`http://<设备IP>/cgi-bin/luci/admin/vpn/openvpn`（实测 200，注意是 **vpn** 不是 services）。

## 安装要点（实测）

| 项 | 处理 |
|---|---|
| OpenVPN 二进制 | 官方源 `openvpn-openssl` 2.7.7（匹配设备 openssl 3.5.x） |
| DCO 模块 | snapshot 源实缺 `kmod-ovpn-backports` → 空虚拟包 `apk add --virtual` 绕过，`DCO version: N/A` 回退用户态 |
| LuCI 前端 | 仓库 apk 26.262（纯前端，不挑内核） |
| init 脚本 | 官方 2.7.7 不含 `/etc/init.d/openvpn`（改 netifd proto），脚本从仓库 src 补 init + `/lib/functions/openvpn.sh` |

## 踩坑记录

1. **CRLF（最隐蔽）**：仓库 blob 本是 LF，但 Windows 全局 `core.autocrlf=true` 会在工作区把脚本转成 CRLF，直接部署会让 busybox ash 解析失败。仓库根已加 `.gitattributes`（`eol=lf`）根治。
2. **DCO 绕过**：与 TR3000 相同，空虚拟包方式；N/A 属正常。
3. **官方包结构变化**：2.7.7 无 init.d，需自行补；脚本已处理。
4. 设备**无 SFTP 子系统**，大文件传输用 HTTP/U盘，勿依赖 SFTP。
