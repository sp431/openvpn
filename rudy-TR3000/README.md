# OpenVPN - rudy-TR3000 (Cudy TR3000)

## 设备信息

| 项目 | 值 |
|------|-----|
| 型号 | Cudy TR3000 256MB v1 |
| 架构 | aarch64_cortex-a53 |
| 系统 | OpenWrt 25.12.4 (r32933-4ccb782af7)，定制固件 FanchmWrt |
| 目标 | mediatek/filogic |
| 内核 | 6.12.87 |
| 包管理器 | **apk**（apk-tools 3.x，不是 opkg） |

## 已安装版本（2026-09-22 实测）

| 包名 | 版本 | 架构 | 说明 |
|------|------|------|------|
| openvpn-openssl | 2.7.6-r1 | aarch64_cortex-a53 | 主程序 |
| luci-app-openvpn | 26.262.64656~abf63e6 | noarch | LuCI 界面 |
| luci-i18n-openvpn-zh-cn | 26.262.64656~abf63e6 | noarch | 中文语言包 |
| libopenssl3 | 3.5.7-r1 | aarch64_cortex-a53 | 依赖 |
| liblzo2 | 2.10-r5 | aarch64_cortex-a53 | LZO 压缩 |
| liblz4-1 | 1.10.0-r1 | aarch64_cortex-a53 | LZ4 压缩 |
| libnl-genl200 | 3.12.0-r1 | aarch64_cortex-a53 | netlink 依赖 |
| libcap-ng | 0.8.4-r2 | aarch64_cortex-a53 | 权限能力库 |

8 个包在本仓库 `packages/` 中**全部齐全**，可离线安装。

实测状态：`DCO version: N/A`（回退用户态，见下文），TUN 设备正常，服务已设开机自启，
LuCI 页面 `admin/vpn/openvpn` 返回 200。

## 安装方法

### 方法 1：一键脚本（推荐）

```sh
cd /tmp/rudy-TR3000
sh scripts/install-openvpn.sh
```

脚本会自动处理 **DCO 内核模块缺失** 这个必踩的坑（见下文），无需人工干预。

### 方法 2：手动安装

```sh
apk update

# 关键一步：先创建空虚拟包满足 kmod-ovpn-backports 依赖
# （该内核模块在定制固件中不存在，详见下文）
apk add --virtual kmod-ovpn-backports

# 再一次性装齐
apk add --allow-untrusted packages/*.apk
# 或从在线源装：
# apk add openvpn-openssl luci-app-openvpn luci-i18n-openvpn-zh-cn

/etc/init.d/openvpn enable
rm -f /tmp/luci-indexcache* ; rm -rf /tmp/luci-modulecache
/etc/init.d/rpcd restart
```

### 方法 3：部署 src/ 源码

```sh
cd src && tar -cf - etc usr | (cd / && tar -xf -)
chmod 755 /etc/init.d/openvpn
chmod 755 /usr/sbin/openvpn
/etc/init.d/openvpn enable
```

## 关键坑：`kmod-ovpn-backports` 依赖无法满足

### 现象

```sh
apk add openvpn-openssl
# 报错：unsatisfiable constraints:
#   openvpn-openssl-2.7.6-r1[SO:...] -> kmod-ovpn-backports
```

`apk list --all | grep ovpn` 也搜不到该包 —— 官方源里确实有它，
但本设备的内核（6.12.87，定制固件 FanchmWrt）**没有编译这个模块**，
而 apk 会强制校验依赖声明，于是安装被直接拒绝。

### 原理

OpenWrt 25.12 的 `openvpn-openssl` 依赖 `kmod-ovpn-backports`，
它提供的是 **DCO（Data Channel Offload）内核加速模块**。
这只是一个**可选性能优化**：没有它，OpenVPN 会自动回退到传统的用户态数据通道，
功能完全不受影响，只是吞吐略低。

### 解决

用一个**空虚拟包**占位，满足依赖声明：

```sh
apk add --virtual kmod-ovpn-backports
```

然后再安装 OpenVPN 即可成功。

### 验证

```sh
openvpn --version | head -3
# 预期看到: DCO version: N/A     <- 属正常，表示未加载内核加速

ls -l /dev/net/tun              # TUN 设备应存在（透明代理必需）
/etc/init.d/openvpn enabled && echo "已设开机自启"
```

## LuCI 访问路径

注意 OpenVPN 的菜单**不在 services 下**，而在 **vpn** 下：

```
http://<设备IP>/cgi-bin/luci/admin/vpn/openvpn
```

## 配置说明

1. 将 OpenVPN 配置文件（`.ovpn`）放入 `/etc/openvpn/` 目录
2. 通过 UCI 配置实例：

```sh
uci set openvpn.my_instance=openvpn
uci set openvpn.my_instance.config='/etc/openvpn/my_config.ovpn'
uci set openvpn.my_instance.enabled='1'
uci commit openvpn
/etc/init.d/openvpn restart
```

## 不学习服务器推送的路由

若只想用 OpenVPN 而不让服务端路由覆盖默认路由，在 `.ovpn` 文件里加：

```
route-nopull
```

## 注意事项

- OpenVPN 2.7.6 使用 OpenSSL 3.5.7
- 支持 LZO 与 LZ4 压缩
- 此设备使用 apk 包管理器（非 opkg）；busybox 无 `stat`，查大小用 `wc -c`
- 全局 DCO 不可用属预期行为，无需尝试修复
