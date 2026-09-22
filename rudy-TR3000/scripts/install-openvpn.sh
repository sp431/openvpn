#!/bin/sh
# ============================================================
# OpenVPN 一键安装脚本
# 目标设备: Cudy TR3000 256MB v1 / OpenWrt 25.12.4 (apk)
# 用法: cd /tmp/rudy-TR3000 && sh scripts/install-openvpn.sh
#
# 本脚本处理的关键问题:
#   openvpn-openssl 依赖 kmod-ovpn-backports（DCO 内核加速模块），
#   而定制固件（内核 6.12.87）未编译该模块，导致安装被 apk 拒绝。
#   解决方式：先用空虚拟包占位满足依赖，再装 OpenVPN。
#   装完后 DCO 显示 N/A 属正常，OpenVPN 会自动回退用户态数据通道。
# ============================================================
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
PKG="$HERE/../packages"
SRC="$HERE/../src"

log() { echo "[openvpn] $*"; }
warn() { echo "[openvpn][WARN] $*" >&2; }

[ -x /sbin/apk ] || { echo "错误: 未检测到 apk，本脚本仅适用于 OpenWrt 25.x+"; exit 1; }

# ---------- 0. 备份 ----------
BAK="/root/_ovpn_backup_$(date +%Y%m%d%H%M%S)"
log "0/5 备份到 $BAK"
mkdir -p "$BAK"
cp -f /etc/apk/world "$BAK"/world.bak 2>/dev/null
[ -d /etc/openvpn ] && cp -r /etc/openvpn "$BAK"/ 2>/dev/null
[ -f /etc/config/openvpn ] && cp -f /etc/config/openvpn "$BAK"/ 2>/dev/null

# ---------- 1. 环境检查 ----------
log "1/5 检查 TUN 支持（OpenVPN 必需）"
if [ -c /dev/net/tun ]; then
    log "    TUN 设备存在: /dev/net/tun"
else
    warn "未找到 /dev/net/tun，请确认内核已启用 CONFIG_TUN"
fi

# ---------- 2. 绕过 DCO 内核模块依赖 ----------
log "2/5 创建空虚拟包满足 kmod-ovpn-backports 依赖"
if apk info -e kmod-ovpn-backports >/dev/null 2>&1; then
    log "    虚拟包已存在，跳过"
else
    apk add --virtual kmod-ovpn-backports || \
        warn "虚拟包创建失败，后续 openvpn-openssl 可能因依赖失败而装不上"
fi

# ---------- 3. 安装 ----------
log "3/5 安装 OpenVPN 与 LuCI 前端"
apk update || warn "apk update 失败，请检查 /etc/apk/repositories"

if ls "$PKG"/*.apk >/dev/null 2>&1; then
    log "    使用本仓库 packages/ 离线安装"
    # 一次性装齐，避免中途失败在 /etc/apk/world 留下未满足的约束
    apk add --allow-untrusted "$PKG"/*.apk || \
        warn "离线安装失败；可改为在线源：apk add openvpn-openssl luci-app-openvpn luci-i18n-openvpn-zh-cn"
else
    log "    改为在线源安装"
    apk add openvpn-openssl luci-app-openvpn luci-i18n-openvpn-zh-cn || \
        warn "安装失败，请检查软件源"
fi

# ---------- 4. 部署 src/（可选，覆盖为仓库版本） ----------
if [ -d "$SRC" ]; then
    log "4/5 部署 src/ 到根文件系统（覆盖同名文件）"
    cd "$SRC" || exit 1
    tar -cf - etc usr | (cd / && tar -xf -)
    chmod 755 /etc/init.d/openvpn 2>/dev/null
    chmod 755 /usr/sbin/openvpn 2>/dev/null
else
    log "4/5 跳过（无 src 目录）"
fi

# ---------- 5. 生效与验证 ----------
log "5/5 清缓存、启用服务并验证"
rm -f /tmp/luci-indexcache* 2>/dev/null
rm -rf /tmp/luci-modulecache 2>/dev/null
/etc/init.d/openvpn enable 2>/dev/null
/etc/init.d/rpcd restart 2>/dev/null

if command -v openvpn >/dev/null 2>&1; then
    log "    版本信息:"
    openvpn --version 2>/dev/null | head -3 | sed 's/^/      /'
    log "    （DCO version: N/A 属正常，表示未加载内核加速模块）"
else
    warn "openvpn 命令不可用，安装可能未成功"
fi

log "安装完成。"
log "访问: http://<设备IP>/cgi-bin/luci/admin/vpn/openvpn  （注意是 vpn，不是 services）"
