# OpenVPN - rudy-TR3000 (Cudy TR3000)

## 设备信息
- 型号: Cudy TR3000 256MB v1
- 架构: aarch64_cortex-a53
- 系统: OpenWrt 25.12.4 (r32933-4ccb782af7)
- 目标: mediatek/filogic

## 已安装包

| 包名 | 版本 | 架构 |
|------|------|------|
| openvpn-openssl | 2.7.6-r1 | aarch64_cortex-a53 |
| luci-app-openvpn | 26.255.67114~2629964 | noarch |
| luci-i18n-openvpn-zh-cn | 26.255.67114~2629964 | noarch |

## 安装方法

### 方法1: 通过 apk 安装（推荐）

```bash
# 更新包索引
apk update

# 安装 OpenVPN 及 LuCI 前端
apk add openvpn-openssl luci-app-openvpn luci-i18n-openvpn-zh-cn
```

### 方法2: 从本仓库安装

1. 将 `src/` 目录中的文件复制到路由器对应路径
2. 将 `packages/` 中的二进制文件复制到 `/usr/sbin/` 和 `/usr/lib/lua/`

```bash
# 复制 openvpn 二进制
cp src/usr/sbin/openvpn /usr/sbin/openvpn
chmod +x /usr/sbin/openvpn

# 复制 LuCI 控制器
mkdir -p /usr/lib/lua/luci/controller
cp src/usr/lib/lua/luci/controller/openvpn.lua /usr/lib/lua/luci/controller/

# 复制 CBI 模型
mkdir -p /usr/lib/lua/luci/model/cbi/openvpn
cp -r src/usr/lib/lua/luci/model/cbi/openvpn/* /usr/lib/lua/luci/model/cbi/openvpn/

# 复制 init 脚本
cp src/etc/init.d/openvpn /etc/init.d/openvpn
chmod +x /etc/init.d/openvpn
/etc/init.d/openvpn enable
```

## 配置说明

1. 将 OpenVPN 配置文件（.ovpn）放入 `/etc/openvpn/` 目录
2. 通过 UCI 配置 OpenVPN 实例：

```bash
# 创建实例
uci set openvpn.my_instance=openvpn
uci set openvpn.my_instance.config='/etc/openvpn/my_config.ovpn'
uci set openvpn.my_instance.enabled='1'
uci commit openvpn
/etc/init.d/openvpn restart
```

## 防止学习服务器路由

如果需要禁止从服务器推送的路由，在 .ovpn 配置文件中添加：

```
route-nopull
```

## 注意事项

- OpenVPN 2.7.6 使用 OpenSSL 3.5.6
- 支持 LZO 和 LZ4 压缩
- 此设备使用 apk 包管理器（非 opkg）
