#!/bin/sh
# ============================================================
# OpenVPN 一键安装脚本（Tenda BE12 Pro 专用）
# 目标设备: Tenda BE12 Pro / OpenWrt SNAPSHOT r34613 (FanchmWrt)
#           内核 6.18.31, aarch64_cortex-a53, apk, 512MB, overlay 65MB
# 用法: cd /tmp/openvpn && sh BE12_Pro/scripts/install-openvpn.sh
#
# 实测可行路径（2026-09-22）：
#   * OpenVPN 二进制 = 官方源 openvpn-openssl 2.7.7（与设备 openssl 3.5.x 匹配）
#   * DCO 模块 kmod-ovpn-backports 在 snapshot 源实缺 -> 空虚拟包绕过，
#     DCO version: N/A，自动回退用户态
#   * LuCI 前端 = 本仓库 apk（26.262，纯前端不挑内核）
#   * ⚠️ 官方 openvpn-openssl 2.7.7 不含 /etc/init.d/openvpn（新版改 netifd
#     proto），脚本从仓库 rudy-TR3000/src 补 init + functions
# ============================================================
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
ROOTDIR="$HERE/../.."
LEGACY_SRC="$ROOTDIR/rudy-TR3000/src"
LEGACY_PKG="$ROOTDIR/rudy-TR3000/packages"
STAGE="/tmp/ovpn_pkgs"

log()  { echo "[openvpn] $*"; }
warn() { echo "[openvpn][WARN] $*" >&2; }

[ -x /sbin/apk ] || { echo "错误: 未检测到 apk"; exit 1; }

# ---------- 0. 备份 ----------
BAK="/root/_ovpn_backup_$(date +%Y%m%d%H%M%S)"
log "0/5 备份到 $BAK"; mkdir -p "$BAK"
for p in /etc/init.d/openvpn /etc/openvpn /etc/config/openvpn /etc/apk/world; do
    [ -e "$p" ] && cp -r "$p" "$BAK"/ 2>/dev/null
done

# ---------- 1. TUN 检查 ----------
log "1/5 检查 TUN"
[ -c /dev/net/tun ] && log "    /dev/net/tun 存在" || warn "无 /dev/net/tun"

# ---------- 2. DCO 空虚拟包 + 装官方 openvpn ----------
log "2/5 绕过 DCO 依赖并安装官方 openvpn-openssl 2.7.7"
if apk info -e kmod-ovpn-backports >/dev/null 2>&1; then
    log "    kmod-ovpn-backports 已存在"
else
    apk add --virtual kmod-ovpn-backports || warn "空虚拟包创建失败"
fi
apk add openvpn-openssl || { warn "openvpn-openssl 安装失败"; exit 1; }

# ---------- 3. LuCI 前端（仓库 apk，不挑内核） ----------
log "3/5 安装 LuCI 前端"
mkdir -p "$STAGE"; rm -f "$STAGE"/*.apk
# 从仓库 packages 中挑出 LuCI 前端与中文包（若仓库已在设备上直接用，
# 否则从 GitHub raw 下载）
if ls "$LEGACY_PKG"/luci-app-openvpn*.apk >/dev/null 2>&1; then
    cp "$LEGACY_PKG"/luci-app-openvpn*.apk "$STAGE"/ 2>/dev/null
    cp "$LEGACY_PKG"/luci-i18n-openvpn*.apk "$STAGE"/ 2>/dev/null
else
    PWURL="https://raw.githubusercontent.com/sp431/openvpn/master/rudy-TR3000/packages"
    for f in luci-app-openvpn-26.262.64656~abf63e6.apk \
             luci-i18n-openvpn-zh-cn-26.262.64656~abf63e6.apk; do
        wget -q -T 60 -O "$STAGE/$f" "$PWURL/$f" || warn "下载 $f 失败"
    done
fi
if ls "$STAGE"/*.apk >/dev/null 2>&1; then
    apk add --allow-untrusted "$STAGE"/*.apk || warn "LuCI 前端安装失败"
else
    warn "未取得 LuCI apk"
fi

# ---------- 4. 补 init 脚本（官方 2.7.7 不含） ----------
log "4/5 补 init 服务脚本与 functions"
if [ -f "$LEGACY_SRC/etc/init.d/openvpn" ]; then
    cp "$LEGACY_SRC/etc/init.d/openvpn" /etc/init.d/openvpn
    chmod 755 /etc/init.d/openvpn
else
    wget -q -T 40 -O /etc/init.d/openvpn \
        "https://raw.githubusercontent.com/sp431/openvpn/master/rudy-TR3000/src/etc/init.d/openvpn"
    chmod 755 /etc/init.d/openvpn
fi
# 配套 /lib/functions/openvpn.sh（官方包未带）；本机用精简版
if [ ! -f /lib/functions/openvpn.sh ]; then
cat > /lib/functions/openvpn.sh <<'FUNC'
get_openvpn_option() {
	local cfg="$1"; local var="$2"; local opt="$3"; local s
	config_get "$var" "$cfg" 2>/dev/null
	[ -n "$(eval echo "\${$var:-}")" ] && return
	s=$(sed -e 's/#.*$//' -e 's/^[ \t]*//' -e '/^[ \t]*$/d' "$cfg" | awk 'BEGIN{IGNORECASE=1}
		$1=="'"$opt"'" && NF==2 {print $2; exit}
		$1=="'"$opt"'" && NF>2 {$1=""; sub(/^ /,""); print; exit}')
	[ -n "$s" ] && eval "export $var=\"\$s\""
}
FUNC
fi

# ---------- 5. 启用与验证 ----------
log "5/5 启用开机自启、清缓存"
rm -f /tmp/luci-indexcache* 2>/dev/null
rm -rf /tmp/luci-modulecache 2>/dev/null
/etc/init.d/openvpn enable
/etc/init.d/rpcd restart 2>/dev/null
rm -rf "$STAGE"

if command -v openvpn >/dev/null 2>&1; then
    openvpn --version 2>/dev/null | head -2 | sed 's/^/    /'
fi
log "完成。访问 http://<设备IP>/cgi-bin/luci/admin/vpn/openvpn（注意是 vpn）"
