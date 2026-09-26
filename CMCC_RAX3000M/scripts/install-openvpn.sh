#!/bin/sh
# ============================================================
# OpenVPN 离线一键安装（CMCC RAX3000M 专用）
# 目标: 中国移动 CMCC RAX3000M, MediaTek MT7981B (filogic), aarch64
#       FanchmWrt = OpenWrt 25.12.4 r32933, 内核 6.12.87, apk-tools
# 场景: 设备 /etc/apk/repositories 为空且无 WAN/互联网 -> 纯离线
#
# 用法（把本 CMCC_RAX3000M 目录放到设备后）:
#   cd /tmp/CMCC_RAX3000M && sh scripts/install-openvpn.sh
#
# 实测（2026-09-26）:
#   * openvpn-openssl 2.7.6 自带 /etc/init.d/openvpn（与 2.7.7 不同，
#     无需再补 init）
#   * DCO: 缺 kmod-ovpn-backports -> 空虚拟包占位，回退用户态数据通道
#   * 39 个 apk 一次性装齐（见 packages/SHA256SUMS.txt），
#     apk add 必须一次装齐，否则 /etc/apk/world 残留坏约束会使 apk 瘫痪
# ============================================================
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
PKGDIR="$HERE/../packages"
STAGE="/tmp/apkpool"

log()  { echo "[openvpn] $*"; }
warn() { echo "[openvpn][WARN] $*" >&2; }

[ -x /sbin/apk ] || { echo "错误: 未检测到 apk"; exit 1; }
ls "$PKGDIR"/*.apk >/dev/null 2>&1 || { echo "错误: $PKGDIR 内无 apk"; exit 1; }

# ---------- 0. 备份 ----------
BAK="/root/_ovpn_backup_$(date +%Y%m%d%H%M%S)"
log "0/5 备份到 $BAK"; mkdir -p "$BAK"
for p in /etc/init.d/openvpn /etc/openvpn /etc/config/openvpn /etc/apk/world; do
    [ -e "$p" ] && cp -r "$p" "$BAK"/ 2>/dev/null
done

# ---------- 1. TUN / 内核模块检查 ----------
log "1/5 检查 TUN 与内核模块"
[ -c /dev/net/tun ] && log "    /dev/net/tun 存在" || warn "无 /dev/net/tun（kmod-tun 未内置）"

# ---------- 2. DCO 空虚拟包占位 ----------
log "2/5 占位 kmod-ovpn-backports（DCO 回退用户态）"
if apk info -e kmod-ovpn-backports >/dev/null 2>&1; then
    log "    kmod-ovpn-backports 已存在"
else
    apk add --virtual kmod-ovpn-backports || warn "空虚拟包创建失败"
fi

# ---------- 3. 一次性离线安装全部 apk ----------
log "3/5 离线安装（39 个 apk，一次性装齐）"
mkdir -p "$STAGE"; rm -f "$STAGE"/*.apk
cp "$PKGDIR"/*.apk "$STAGE"/
N=$(ls "$STAGE"/*.apk | wc -l); log "    待装 $N 个包"
apk add --allow-untrusted "$STAGE"/*.apk || {
    warn "批量安装失败。请执行: apk add --allow-untrusted --simulate $STAGE/*.apk"
    warn "根据 'missing' 输出补齐依赖后重跑，勿半途残留。"
    exit 1
}

# ---------- 4. 清 LuCI 缓存 / 重启 rpcd ----------
log "4/5 刷新 LuCI 缓存并重启 rpcd"
rm -f /tmp/luci-indexcache* 2>/dev/null
rm -rf /tmp/luci-modulecache 2>/dev/null
/etc/init.d/rpcd restart 2>/dev/null

# ---------- 5. 启用自启 + 验证 ----------
log "5/5 启用开机自启并验证"
/etc/init.d/openvpn enable
echo "    ---- openvpn 版本 ----"
openvpn --version 2>/dev/null | head -1 | sed 's/^/    /'
echo "    ---- init 脚本 ----"
[ -f /etc/init.d/openvpn ] && echo "    /etc/init.d/openvpn 存在" || warn "缺 init"
echo "    ---- LuCI 前端 ----"
ls "$PKGDIR"/luci-app-openvpn*.apk >/dev/null 2>&1 && echo "    luci-app-openvpn 已离线装入"
rm -rf "$STAGE"

log "完成。页面 http://<设备IP>/cgi-bin/luci/admin/vpn/openvpn（注意是 vpn 段）"
