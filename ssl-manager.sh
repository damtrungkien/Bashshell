#!/usr/bin/env bash
#===============================================================================
# AZDIGI Universal SSL Manager
# Cài đặt / gia hạn SSL Let's Encrypt đa nền tảng bằng acme.sh
#
# Hỗ trợ : cPanel (user & root/WHM), DirectAdmin, aaPanel/BT, CyberPanel,
#          Plesk, HestiaCP/VestaCP và VPS không panel (nginx / apache / OLS)
# Tác giả : AZDIGI
#===============================================================================

VERSION="1.1"
ACME_EMAIL="${ACME_EMAIL:-ssl@azdigi.info}"
KEYLENGTH="${KEYLENGTH:-2048}"          # 2048 | 3072 | 4096 | ec-256 | ec-384
CERT_STORE="/etc/ssl/azdigi"            # nơi lưu cert khi không có panel
LOG_FILE="/tmp/azdigi-ssl-$(date +%Y%m%d).log"

# Nhà cung cấp chứng chỉ: letsencrypt | zerossl | buypass | auto
#   auto = thử Let's Encrypt trước, thất bại (rate limit...) thì tự chuyển ZeroSSL
CA_SERVER="${CA_SERVER:-auto}"
CA_FALLBACK_ORDER="letsencrypt zerossl"
# EAB của ZeroSSL — để trống thì acme.sh tự lấy bằng email đăng ký
ZEROSSL_EAB_KID="${ZEROSSL_EAB_KID:-}"
ZEROSSL_EAB_HMAC="${ZEROSSL_EAB_HMAC:-}"

#------------------------------------------------------------------------------
# Màu sắc & tiện ích hiển thị
#------------------------------------------------------------------------------
if [ -t 1 ]; then
    RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YLW=$'\033[1;33m'
    BLU=$'\033[0;34m'; CYN=$'\033[0;36m'; BLD=$'\033[1m'; NC=$'\033[0m'
else
    RED=""; GRN=""; YLW=""; BLU=""; CYN=""; BLD=""; NC=""
fi

info()  { printf '%s[*]%s %s\n' "$BLU" "$NC" "$*"; }
ok()    { printf '%s[✓]%s %s\n' "$GRN" "$NC" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$YLW" "$NC" "$*"; }
err()   { printf '%s[✗]%s %s\n' "$RED" "$NC" "$*" >&2; }
title() { printf '\n%s%s%s\n' "$BLD$CYN" "$*" "$NC"; }
log()   { printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$LOG_FILE" 2>/dev/null; }

pause() { printf '\n'; read -r -p "Nhấn [Enter] để quay lại menu..." _; }

ask() { # ask <biến> <câu hỏi> [giá trị mặc định]
    local __var="$1" __q="$2" __def="${3:-}" __ans
    if [ -n "$__def" ]; then
        read -r -p "$__q [$__def]: " __ans
        __ans="${__ans:-$__def}"
    else
        read -r -p "$__q: " __ans
    fi
    printf -v "$__var" '%s' "$__ans"
}

confirm() { # confirm "câu hỏi"  -> 0 nếu y
    local a
    read -r -p "$1 (y/N): " a
    [[ "$a" =~ ^[Yy]$ ]]
}

#------------------------------------------------------------------------------
# Chuẩn hoá & kiểm tra domain
#------------------------------------------------------------------------------
normalize_domain() {
    local d="$1"
    d="${d,,}"
    d="${d#http://}"; d="${d#https://}"
    d="${d%%/*}"; d="${d%%:*}"
    d="${d%.}"
    printf '%s' "$d"
}

valid_domain() {
    [[ "$1" =~ ^([a-z0-9_]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$ ]]
}

# Kiểm tra domain có phải subdomain (nhiều hơn 2 cấp, bỏ qua TLD 2 thành phần)
is_subdomain() {
    local d="$1" labels
    labels=$(awk -F'.' '{print NF}' <<<"$d")
    if [[ "$d" =~ \.(com|net|org|edu|gov|co|ac|biz|info)\.[a-z]{2}$ ]]; then
        [ "$labels" -gt 3 ]
    else
        [ "$labels" -gt 2 ]
    fi
}

#------------------------------------------------------------------------------
# Phát hiện môi trường
#------------------------------------------------------------------------------
PANEL=""          # cpanel | directadmin | aapanel | cyberpanel | plesk | hestia | none
PANEL_NAME=""
WEBSERVER=""      # nginx | apache | openlitespeed | unknown
WEBSERVER_SVC=""
IS_ROOT=0

detect_privileges() { [ "$(id -u)" -eq 0 ] && IS_ROOT=1 || IS_ROOT=0; }

detect_panel() {
    if [ -e /usr/local/cpanel/cpanel ] || [ -d "$HOME/.cpanel" ] || command -v uapi >/dev/null 2>&1; then
        PANEL="cpanel";      PANEL_NAME="cPanel"
    elif [ -x /usr/local/directadmin/directadmin ]; then
        PANEL="directadmin"; PANEL_NAME="DirectAdmin"
    elif [ -d /usr/local/CyberCP ] || [ -f /usr/local/CyberCP/CyberCP/settings.py ]; then
        PANEL="cyberpanel";  PANEL_NAME="CyberPanel"
    elif [ -d /www/server/panel ]; then
        PANEL="aapanel";     PANEL_NAME="aaPanel / BT Panel"
    elif [ -f /usr/local/psa/version ]; then
        PANEL="plesk";       PANEL_NAME="Plesk $(cat /usr/local/psa/version 2>/dev/null | awk '{print $1}')"
    elif [ -d /usr/local/hestia ]; then
        PANEL="hestia";      PANEL_NAME="HestiaCP"
    elif [ -d /usr/local/vesta ]; then
        PANEL="hestia";      PANEL_NAME="VestaCP"
    else
        PANEL="none";        PANEL_NAME="Không dùng panel"
    fi
}

detect_webserver() {
    # OpenLiteSpeed / LiteSpeed
    if [ -x /usr/local/lsws/bin/litespeed ] || [ -x /usr/local/lsws/bin/openlitespeed ] \
       || pgrep -x litespeed >/dev/null 2>&1 || pgrep -x openlitespeed >/dev/null 2>&1; then
        WEBSERVER="openlitespeed"; WEBSERVER_SVC="lsws"
    fi
    # nginx (ưu tiên nếu đang chạy ở cổng 80/443)
    if command -v nginx >/dev/null 2>&1 && (pgrep -x nginx >/dev/null 2>&1 || [ -z "$WEBSERVER" ]); then
        WEBSERVER="nginx"; WEBSERVER_SVC="nginx"
    fi
    # apache
    if [ -z "$WEBSERVER" ] || ! pgrep -x nginx >/dev/null 2>&1; then
        if pgrep -x httpd >/dev/null 2>&1 || pgrep -x apache2 >/dev/null 2>&1; then
            WEBSERVER="apache"
            if systemctl list-unit-files 2>/dev/null | grep -q '^httpd\.service'; then
                WEBSERVER_SVC="httpd"
            else
                WEBSERVER_SVC="apache2"
            fi
        fi
    fi
    [ -z "$WEBSERVER" ] && { WEBSERVER="unknown"; WEBSERVER_SVC=""; }

    # Panel đặc thù ghi đè
    case "$PANEL" in
        cpanel)     WEBSERVER="apache"; WEBSERVER_SVC="httpd" ;;
        cyberpanel) WEBSERVER="openlitespeed"; WEBSERVER_SVC="lsws" ;;
    esac
}

reload_cmd() {
    case "$WEBSERVER" in
        nginx)          echo "nginx -t && systemctl reload nginx || service nginx reload" ;;
        apache)         echo "systemctl reload ${WEBSERVER_SVC:-httpd} || service ${WEBSERVER_SVC:-httpd} reload" ;;
        openlitespeed)  echo "/usr/local/lsws/bin/lswsctrl restart" ;;
        *)              echo "true" ;;
    esac
}

do_reload() {
    [ "$IS_ROOT" -eq 1 ] || return 0
    info "Reload web server ($WEBSERVER)..."
    eval "$(reload_cmd)" >>"$LOG_FILE" 2>&1 \
        && ok "Đã reload $WEBSERVER" \
        || warn "Reload thất bại, kiểm tra $LOG_FILE"
}

#------------------------------------------------------------------------------
# Cài đặt acme.sh
#------------------------------------------------------------------------------
ACME=""

find_acme() {
    local c
    for c in "$HOME/.acme.sh/acme.sh" /root/.acme.sh/acme.sh /home/*/.acme.sh/acme.sh; do
        [ -x "$c" ] && { ACME="$c"; return 0; }
    done
    command -v acme.sh >/dev/null 2>&1 && { ACME="$(command -v acme.sh)"; return 0; }
    return 1
}

install_acme() {
    if find_acme; then
        info "acme.sh đã có: $ACME"
    else
        info "Đang cài đặt acme.sh..."
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL https://get.acme.sh | sh -s email="$ACME_EMAIL" >>"$LOG_FILE" 2>&1
        elif command -v wget >/dev/null 2>&1; then
            wget -qO- https://get.acme.sh | sh -s email="$ACME_EMAIL" >>"$LOG_FILE" 2>&1
        else
            err "Cần curl hoặc wget để cài acme.sh"; return 1
        fi
        find_acme || { err "Cài acme.sh thất bại. Xem log: $LOG_FILE"; return 1; }
        ok "Đã cài acme.sh: $ACME"
    fi
    # Đặt CA mặc định (acme.sh >= 3.0 mặc định ZeroSSL, ta chủ động chọn)
    local def="$CA_SERVER"
    [ "$def" = "auto" ] && def="letsencrypt"
    "$ACME" --set-default-ca --server "$def" >>"$LOG_FILE" 2>&1
    register_ca "$def" quiet
    return 0
}

#------------------------------------------------------------------------------
# Quản lý nhà cung cấp chứng chỉ (CA)
#------------------------------------------------------------------------------
ca_label() {
    case "$1" in
        letsencrypt) echo "Let's Encrypt" ;;
        zerossl)     echo "ZeroSSL" ;;
        buypass)     echo "Buypass" ;;
        auto)        echo "Auto (LE → ZeroSSL)" ;;
        *)           echo "$1" ;;
    esac
}

# Danh sách CA sẽ thử theo thứ tự, ứng với CA_SERVER hiện tại
ca_try_list() {
    if [ "$CA_SERVER" = "auto" ]; then
        printf '%s\n' $CA_FALLBACK_ORDER
    else
        printf '%s\n' "$CA_SERVER"
    fi
}

# Đăng ký account cho một CA. ZeroSSL cần EAB (acme.sh tự lấy qua email).
register_ca() { # register_ca <ca> [quiet]
    local ca="$1" quiet="${2:-}"
    local -a o=(--register-account -m "$ACME_EMAIL" --server "$ca" --log "$LOG_FILE")

    # Đã đăng ký rồi thì bỏ qua cho nhanh
    local acc
    case "$ca" in
        letsencrypt) acc="$HOME/.acme.sh/ca/acme-v02.api.letsencrypt.org" ;;
        zerossl)     acc="$HOME/.acme.sh/ca/acme.zerossl.com" ;;
        buypass)     acc="$HOME/.acme.sh/ca/api.buypass.com" ;;
    esac
    if [ -n "$acc" ] && find "$acc" -name 'account.key' 2>/dev/null | grep -q .; then
        [ "$quiet" = "quiet" ] || info "Account $(ca_label "$ca") đã đăng ký"
        return 0
    fi

    if [ "$ca" = "zerossl" ] && [ -n "$ZEROSSL_EAB_KID" ] && [ -n "$ZEROSSL_EAB_HMAC" ]; then
        o+=(--eab-kid "$ZEROSSL_EAB_KID" --eab-hmac-key "$ZEROSSL_EAB_HMAC")
        info "Đăng ký ZeroSSL bằng EAB credentials"
    elif [ "$ca" = "zerossl" ]; then
        info "Đăng ký ZeroSSL bằng email $ACME_EMAIL (acme.sh tự lấy EAB)"
    fi

    if "$ACME" "${o[@]}" >>"$LOG_FILE" 2>&1; then
        [ "$quiet" = "quiet" ] || ok "Đã đăng ký account $(ca_label "$ca")"
        return 0
    fi
    [ "$quiet" = "quiet" ] || warn "Đăng ký account $(ca_label "$ca") thất bại — xem $LOG_FILE"
    return 1
}

#------------------------------------------------------------------------------
# Đọc JSON đơn giản (không phụ thuộc jq)
#------------------------------------------------------------------------------
json_get() { # json_get "<json>" "<key>"
    local json="$1" key="$2"
    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$json" | python3 -c "
import sys, json
def walk(o, k):
    if isinstance(o, dict):
        if k in o and not isinstance(o[k], (dict, list)): return o[k]
        for v in o.values():
            r = walk(v, k)
            if r is not None: return r
    elif isinstance(o, list):
        for v in o:
            r = walk(v, k)
            if r is not None: return r
    return None
try:
    print(walk(json.load(sys.stdin), '$key') or '')
except Exception:
    print('')
" 2>/dev/null
    else
        printf '%s' "$json" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
            | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//'
    fi
}

#------------------------------------------------------------------------------
# Phân tích vhost — tìm DocumentRoot và đường dẫn cert đang khai báo
#------------------------------------------------------------------------------
esc_re() { printf '%s' "$1" | sed 's/[.[\*^$()+?{}|]/\\&/g'; }

# Trả về nội dung server block của nginx chứa domain
nginx_server_block() {
    local d de
    d="$1"; de="$(esc_re "$d")"
    nginx -T 2>/dev/null | awk -v re="$de" '
        /^[[:space:]]*server[[:space:]]*\{/ && !inblk { inblk=1; buf=""; depth=0 }
        inblk {
            buf = buf $0 "\n"
            depth += gsub(/\{/, "{")
            depth -= gsub(/\}/, "}")
            if (depth <= 0) {
                if (buf ~ ("server_name[^;]*[[:space:]]" re "([[:space:];]|$)") ||
                    buf ~ ("server_name[[:space:]]+" re "([[:space:];]|$)"))
                    print buf
                inblk = 0; buf = ""
            }
        }'
}

apache_vhost_file() {
    local d de f
    d="$1"; de="$(esc_re "$d")"
    f=$(apachectl -S 2>/dev/null | grep -E "namevhost[[:space:]]+$de([[:space:]]|$)" \
        | head -1 | sed -n 's/.*(\(.*\):[0-9]*).*/\1/p')
    [ -n "$f" ] && [ -f "$f" ] && { printf '%s' "$f"; return 0; }
    # Fallback: quét thư mục cấu hình phổ biến
    local dir
    for dir in /etc/httpd/conf.d /etc/apache2/sites-enabled /etc/apache2/conf.d \
               /usr/local/apache/conf/userdata /www/server/panel/vhost/apache; do
        [ -d "$dir" ] || continue
        f=$(grep -rlE "ServerName[[:space:]]+$de([[:space:]]|$)" "$dir" 2>/dev/null | head -1)
        [ -n "$f" ] && { printf '%s' "$f"; return 0; }
    done
    return 1
}

# Xuất ra: VHOST_FILE, VHOST_CERT, VHOST_KEY, VHOST_CHAIN, DOCROOT
VHOST_FILE=""; VHOST_CERT=""; VHOST_KEY=""; VHOST_CHAIN=""; DOCROOT=""

parse_vhost() {
    local d="$1" blk file
    VHOST_FILE=""; VHOST_CERT=""; VHOST_KEY=""; VHOST_CHAIN=""

    case "$WEBSERVER" in
        nginx)
            blk="$(nginx_server_block "$d")"
            if [ -n "$blk" ]; then
                [ -z "$DOCROOT" ] && DOCROOT=$(grep -m1 -E '^[[:space:]]*root[[:space:]]' <<<"$blk" \
                    | sed 's/.*root[[:space:]]*//; s/;.*//; s/["'\'']//g; s#/*$##')
                VHOST_CERT=$(grep -m1 -E '^[[:space:]]*ssl_certificate[[:space:]]' <<<"$blk" \
                    | sed 's/.*ssl_certificate[[:space:]]*//; s/;.*//; s/["'\'']//g')
                VHOST_KEY=$(grep -m1 -E '^[[:space:]]*ssl_certificate_key[[:space:]]' <<<"$blk" \
                    | sed 's/.*ssl_certificate_key[[:space:]]*//; s/;.*//; s/["'\'']//g')
            fi
            VHOST_FILE=$(grep -rlE "server_name[^;]*[[:space:]]$(esc_re "$d")([[:space:];]|$)" \
                /etc/nginx /usr/local/nginx/conf /www/server/panel/vhost/nginx 2>/dev/null | head -1)
            ;;
        apache)
            file="$(apache_vhost_file "$d")" && VHOST_FILE="$file"
            if [ -n "$VHOST_FILE" ]; then
                [ -z "$DOCROOT" ] && DOCROOT=$(grep -m1 -iE '^[[:space:]]*DocumentRoot' "$VHOST_FILE" \
                    | sed 's/.*[Dd]ocument[Rr]oot[[:space:]]*//; s/["'\'']//g; s#/*$##')
                VHOST_CERT=$(grep -m1 -iE '^[[:space:]]*SSLCertificateFile' "$VHOST_FILE" \
                    | sed 's/.*SSLCertificateFile[[:space:]]*//; s/["'\'']//g')
                VHOST_KEY=$(grep -m1 -iE '^[[:space:]]*SSLCertificateKeyFile' "$VHOST_FILE" \
                    | sed 's/.*SSLCertificateKeyFile[[:space:]]*//; s/["'\'']//g')
                VHOST_CHAIN=$(grep -m1 -iE '^[[:space:]]*SSLCertificateChainFile' "$VHOST_FILE" \
                    | sed 's/.*SSLCertificateChainFile[[:space:]]*//; s/["'\'']//g')
            fi
            ;;
        openlitespeed)
            for file in "/usr/local/lsws/conf/vhosts/$d/vhost.conf" \
                        "/usr/local/lsws/conf/vhosts/$d/vhconf.conf"; do
                [ -f "$file" ] && { VHOST_FILE="$file"; break; }
            done
            if [ -n "$VHOST_FILE" ]; then
                [ -z "$DOCROOT" ] && DOCROOT=$(grep -m1 -E '^[[:space:]]*docRoot' "$VHOST_FILE" \
                    | awk '{print $2}' | sed 's#/*$##')
                VHOST_CERT=$(grep -m1 -E '^[[:space:]]*certFile' "$VHOST_FILE" | awk '{print $2}')
                VHOST_KEY=$(grep -m1 -E '^[[:space:]]*keyFile'  "$VHOST_FILE" | awk '{print $2}')
            fi
            ;;
    esac
}

#------------------------------------------------------------------------------
# Tìm DocumentRoot theo từng panel
#------------------------------------------------------------------------------
DOMAIN_USER=""   # user sở hữu domain (cPanel/DA)

find_docroot() {
    local d="$1" out
    DOCROOT=""; DOMAIN_USER=""

    case "$PANEL" in
    #-------------------------------------------------- cPanel
    cpanel)
        if [ "$IS_ROOT" -eq 1 ] && [ -f /etc/userdatadomains ]; then
            out=$(grep -m1 -i "^$d: " /etc/userdatadomains)
            if [ -n "$out" ]; then
                DOMAIN_USER=$(awk -F'==' '{print $1}' <<<"${out#*: }")
                DOCROOT=$(awk -F'==' '{print $5}' <<<"${out#*: }")
            fi
        elif command -v uapi >/dev/null 2>&1; then
            out=$(uapi --output=json DomainInfo single_domain_data domain="$d" 2>/dev/null)
            DOCROOT=$(json_get "$out" documentroot)
            DOMAIN_USER="$(whoami)"
        fi
        # Fallback theo quy ước cPanel
        if [ -z "$DOCROOT" ]; then
            if [ -d "$HOME/$d" ];              then DOCROOT="$HOME/$d"
            elif [ -d "$HOME/public_html/$d" ]; then DOCROOT="$HOME/public_html/$d"
            else                                    DOCROOT="$HOME/public_html"
            fi
        fi
        ;;
    #-------------------------------------------------- DirectAdmin
    directadmin)
        local f base sub
        for f in /usr/local/directadmin/data/users/*/domains.list; do
            [ -f "$f" ] || continue
            if grep -qx "$d" "$f" 2>/dev/null; then
                DOMAIN_USER=$(basename "$(dirname "$f")")
                DOCROOT="/home/$DOMAIN_USER/domains/$d/public_html"
                break
            fi
        done
        if [ -z "$DOCROOT" ]; then      # có thể là subdomain của một domain khác
            for f in /usr/local/directadmin/data/users/*/domains.list; do
                [ -f "$f" ] || continue
                while read -r base; do
                    [ -n "$base" ] || continue
                    if [[ "$d" == *".$base" ]]; then
                        DOMAIN_USER=$(basename "$(dirname "$f")")
                        sub="${d%.$base}"
                        DOCROOT="/home/$DOMAIN_USER/domains/$base/public_html/$sub"
                        break 2
                    fi
                done <"$f"
            done
        fi
        ;;
    #-------------------------------------------------- CyberPanel
    cyberpanel)
        [ -d "/home/$d/public_html" ] && DOCROOT="/home/$d/public_html"
        ;;
    #-------------------------------------------------- aaPanel / BT
    aapanel)
        [ -d "/www/wwwroot/$d" ] && DOCROOT="/www/wwwroot/$d"
        ;;
    #-------------------------------------------------- Plesk
    plesk)
        if command -v plesk >/dev/null 2>&1; then
            DOCROOT=$(plesk bin subscription --info "$d" 2>/dev/null \
                | awk -F': ' '/^Domain root/{print $2}')
        fi
        [ -z "$DOCROOT" ] && [ -d "/var/www/vhosts/$d/httpdocs" ] && DOCROOT="/var/www/vhosts/$d/httpdocs"
        ;;
    #-------------------------------------------------- Hestia / Vesta
    hestia)
        for f in /home/*/web/"$d"/public_html; do
            [ -d "$f" ] && { DOCROOT="$f"; DOMAIN_USER=$(awk -F'/' '{print $3}' <<<"$f"); break; }
        done
        ;;
    esac

    # Nếu vẫn chưa có -> đọc từ vhost của web server
    [ -z "$DOCROOT" ] && parse_vhost "$d"

    # Đường dẫn phổ biến cuối cùng
    if [ -z "$DOCROOT" ]; then
        for f in "/var/www/$d" "/var/www/$d/public_html" "/var/www/html/$d" \
                 "/usr/share/nginx/html/$d" "/home/$d/public_html"; do
            [ -d "$f" ] && { DOCROOT="$f"; break; }
        done
    fi

    [ -n "$DOCROOT" ] && [ -d "$DOCROOT" ]
}

#------------------------------------------------------------------------------
# Cấp phát chứng chỉ
#------------------------------------------------------------------------------
ISSUE_METHOD="webroot"   # webroot | standalone | dns

# Tự kiểm tra HTTP-01 trước khi gọi CA — tránh đốt quota vì lỗi cấu hình
precheck_webroot() {
    local d="$1" dir="$DOCROOT/.well-known/acme-challenge" tok body
    command -v curl >/dev/null 2>&1 || return 0
    tok="azdigi-precheck-$$"

    if ! mkdir -p "$dir" 2>/dev/null; then
        warn "Không tạo được $dir — kiểm tra quyền ghi của DocumentRoot"
        return 1
    fi
    printf 'ok-%s' "$tok" >"$dir/$tok" 2>/dev/null || { warn "Không ghi được file test vào $dir"; return 1; }

    # -k vì CA cũng bỏ qua lỗi cert khi bị redirect sang https
    body=$(curl -fsSkL --max-time 15 "http://$d/.well-known/acme-challenge/$tok" 2>/dev/null)
    rm -f "$dir/$tok"
    rmdir "$dir" 2>/dev/null; rmdir "$DOCROOT/.well-known" 2>/dev/null

    if [ "$body" = "ok-$tok" ]; then
        ok "Precheck HTTP-01 thành công — CA sẽ đọc được file xác thực"
        return 0
    fi
    warn "Precheck HTTP-01 THẤT BẠI: http://$d/.well-known/acme-challenge/ không trả về đúng nội dung"
    warn "Nguyên nhân thường gặp: domain chưa trỏ về IP server này, sai DocumentRoot,"
    warn "rule rewrite của WordPress/.htaccess chặn, Cloudflare proxy, hoặc firewall chặn cổng 80."
    return 1
}

CERT_CA_USED=""   # CA đã cấp thành công cho lần chạy gần nhất

# CA đầu tiên chưa nằm trong danh sách đã thử
next_untried_ca() {
    local tried=" $1 " c
    for c in letsencrypt zerossl buypass; do
        [[ "$tried" == *" $c "* ]] || { printf '%s' "$c"; return 0; }
    done
    return 1
}

issue_cert() { # issue_cert <domain chính> <danh sách -d bổ sung...>
    local main="$1"; shift
    local -a dargs=("-d" "$main")
    local x
    for x in "$@"; do dargs+=("-d" "$x"); done

    local -a base=(--issue "${dargs[@]}" --keylength "$KEYLENGTH" --log "$LOG_FILE")

    case "$ISSUE_METHOD" in
        webroot)
            [ -d "$DOCROOT" ] || { err "DocumentRoot không tồn tại: $DOCROOT"; return 1; }
            base+=(--webroot "$DOCROOT")
            info "Xác thực HTTP-01 qua webroot: $DOCROOT"
            ;;
        standalone)
            [ "$IS_ROOT" -eq 1 ] || { err "Chế độ standalone cần quyền root"; return 1; }
            base+=(--standalone)
            warn "Standalone sẽ chiếm cổng 80 — web server sẽ tạm dừng."
            confirm "Tiếp tục?" || return 1
            [ -n "$WEBSERVER_SVC" ] && systemctl stop "$WEBSERVER_SVC" >>"$LOG_FILE" 2>&1
            ;;
        dns)
            if [ -n "$DNS_API" ]; then
                base+=(--dns "$DNS_API")
                info "Xác thực DNS-01 qua API: $DNS_API"
            else
                base+=(--dns --yes-I-know-dns-manual-mode-enough-go-ahead-please)
                warn "Chế độ DNS thủ công: bạn phải tự thêm bản ghi TXT rồi chạy lại bước renew."
            fi
            ;;
    esac

    # CA của cert hiện có (nếu đã từng cấp) — dùng để quyết định có cần --force
    local cur_ca=""
    cert_exists "$main" && cur_ca="$(cert_current_ca "$main")"

    CERT_CA_USED=""
    local -a queue=()
    local q; while read -r q; do [ -n "$q" ] && queue+=("$q"); done < <(ca_try_list)

    local ca rc=1 marker idx=0 attempted=0 tried="" alt
    while [ $idx -lt ${#queue[@]} ]; do
        ca="${queue[$idx]}"; idx=$((idx+1))
        tried="$tried $ca"
        attempted=$((attempted+1))
        [ $attempted -gt 1 ] && warn "Chuyển sang CA dự phòng: $(ca_label "$ca")"

        local -a opts=("${base[@]}" --server "$ca")
        if [ "${FORCE_ISSUE:-0}" = "1" ]; then
            opts+=(--force)
        elif [ -n "$cur_ca" ] && [ "$cur_ca" != "$ca" ]; then
            # Đổi nhà cung cấp: acme.sh sẽ bỏ qua vì cert còn hạn → phải ép cấp lại
            warn "Cert hiện tại do $(ca_label "$cur_ca") cấp — ép cấp lại để chuyển sang $(ca_label "$ca")"
            opts+=(--force)
        fi

        info "Đang cấp chứng chỉ cho: $main $* — CA: $(ca_label "$ca")"
        register_ca "$ca" quiet
        marker=$(( $(wc -l <"$LOG_FILE" 2>/dev/null || echo 0) + 1 ))

        # tee để vừa hiện cho người dùng, vừa lưu log phục vụ phân loại lỗi
        "$ACME" "${opts[@]}" 2>&1 | tee -a "$LOG_FILE"
        rc=${PIPESTATUS[0]}

        if [ $rc -eq 0 ]; then
            CERT_CA_USED="$ca"
            break
        fi

        # acme.sh trả 2 = cert còn hạn, không cần cấp lại
        if [ $rc -eq 2 ] && cert_exists "$main"; then
            warn "Chứng chỉ còn hạn nên acme.sh bỏ qua. Chọn 'Cấp lại' ở bước hỏi để ép cấp mới."
            CERT_CA_USED="${cur_ca:-$ca}"; rc=0; break
        fi

        explain_failure "$marker"

        # Lỗi từ phía domain (DNS sai, 404...) → đổi CA cũng vô ích, dừng luôn
        ca_side_failure "$marker" || break

        # Còn CA trong hàng đợi (chế độ auto) → tự động thử tiếp
        [ $idx -lt ${#queue[@]} ] && continue

        # Hết hàng đợi: đề xuất một CA khác chưa thử
        alt="$(next_untried_ca "$tried")" || break
        printf '\n'
        warn "$(ca_label "$ca") đang chặn yêu cầu này."
        confirm "Thử lại ngay bằng $(ca_label "$alt")?" || break
        queue+=("$alt")
    done

    if [ "$ISSUE_METHOD" = "standalone" ] && [ -n "$WEBSERVER_SVC" ]; then
        systemctl start "$WEBSERVER_SVC" >>"$LOG_FILE" 2>&1
    fi

    if [ $rc -ne 0 ]; then
        err "Cấp chứng chỉ thất bại (mã $rc). Xem log: $LOG_FILE"
        return $rc
    fi
    ok "Đã cấp chứng chỉ cho $main bằng $(ca_label "$CERT_CA_USED")"
    return 0
}

cert_exists() {
    [ -f "$HOME/.acme.sh/$1/$1.cer" ] || [ -f "$HOME/.acme.sh/${1}_ecc/$1.cer" ]
}

# CA đã cấp cert hiện có cho domain — đọc Le_API trong file .conf của acme.sh,
# nếu không có thì suy ra từ Issuer của chứng chỉ
cert_current_ca() {
    local d="$1" conf api f iss
    for conf in "$HOME/.acme.sh/$d/$d.conf" "$HOME/.acme.sh/${d}_ecc/$d.conf"; do
        [ -f "$conf" ] || continue
        api=$(grep -m1 '^Le_API=' "$conf" | cut -d"'" -f2)
        case "$api" in
            *letsencrypt*) echo letsencrypt; return 0 ;;
            *zerossl*)     echo zerossl;     return 0 ;;
            *buypass*)     echo buypass;     return 0 ;;
        esac
    done
    for f in "$HOME/.acme.sh/$d/$d.cer" "$HOME/.acme.sh/${d}_ecc/$d.cer"; do
        [ -f "$f" ] || continue
        iss=$(openssl x509 -in "$f" -noout -issuer 2>/dev/null)
        case "$iss" in
            *"Let's Encrypt"*) echo letsencrypt; return 0 ;;
            *ZeroSSL*)         echo zerossl;     return 0 ;;
            *Buypass*)         echo buypass;     return 0 ;;
        esac
    done
    return 1
}

# Số ngày còn lại của cert (hỗ trợ cả date GNU lẫn BSD)
cert_days_left() {
    local d="$1" f exp es now
    for f in "$HOME/.acme.sh/$d/$d.cer" "$HOME/.acme.sh/${d}_ecc/$d.cer"; do
        [ -f "$f" ] || continue
        exp=$(openssl x509 -in "$f" -noout -enddate 2>/dev/null | cut -d= -f2)
        [ -n "$exp" ] || continue
        es=$(date -d "$exp" +%s 2>/dev/null) \
            || es=$(date -j -f "%b %d %T %Y %Z" "$exp" +%s 2>/dev/null)
        [ -n "$es" ] || continue
        now=$(date +%s)
        echo $(( (es - now) / 86400 ))
        return 0
    done
    return 1
}

# Đọc phần log phát sinh từ dòng thứ <marker> để phân loại lỗi
log_tail_since() { tail -n "+${1:-1}" "$LOG_FILE" 2>/dev/null; }

# --- Các mẫu nhận dạng lỗi (tách riêng để tránh khớp nhầm chuỗi base64 trong log) ---
RE_RATELIMIT='too many (certificates|failed authorizations|registrations|orders)|urn:ietf:params:acme:error:rateLimited|rate ?limit|retryafter=[0-9]{4,}|value is too large|code=.?429|"status":[[:space:]]*429'
RE_EAB='urn:ietf:params:acme:error:externalAccountRequired|externalAccountRequired|(^|[^A-Za-z])EAB([^A-Za-z]|$)'
RE_HTTP01='Invalid response from http|Timeout during connect|connection refused|urn:ietf:params:acme:error:(connection|unauthorized)'
RE_DNSPROB='DNS problem|NXDOMAIN|no valid A records'

# Lỗi thuộc về CA (đáng thử CA khác) chứ không phải lỗi cấu hình/DNS của domain
ca_side_failure() {
    local t; t="$(log_tail_since "$1")"
    grep -qiE "$RE_RATELIMIT" <<<"$t" && return 0
    grep -qE  "$RE_EAB"       <<<"$t" && return 0
    grep -qiE 'urn:ietf:params:acme:error:(serverInternal|badNonce)|Could not (get|create) account|service busy|The service is down' <<<"$t"
}

explain_failure() {
    local t; t="$(log_tail_since "$1")"
    if grep -qiE "$RE_RATELIMIT" <<<"$t"; then
        warn "CA từ chối vì RATE LIMIT / QUOTA của tài khoản."
        if grep -qiE 'retryafter=[0-9]{4,}|value is too large' <<<"$t"; then
            warn "CA yêu cầu chờ rất lâu mới cho thử lại (Retry-After lớn) → tài khoản đã chạm giới hạn."
        fi
        warn "Let's Encrypt: 5 cert trùng tên/tuần · 50 cert/domain gốc/tuần (tính theo domain)."
        warn "ZeroSSL: hạn mức tính theo TÀI KHOẢN (email đăng ký), KHÔNG theo server."
        warn "  → Nhiều VPS dùng chung email $ACME_EMAIL sẽ xài chung một hạn mức và chặn lẫn nhau."
        warn "  → Khắc phục: đổi email riêng cho từng server, hoặc nhập EAB riêng ở menu [9] → 5,"
        warn "     hoặc đơn giản là chuyển sang Let's Encrypt."
    elif grep -qiE "$RE_HTTP01" <<<"$t"; then
        warn "Xác thực HTTP-01 thất bại — kiểm tra: domain đã trỏ đúng IP chưa, DocumentRoot có đúng không,"
        warn "và thư mục /.well-known/acme-challenge/ có bị chặn bởi rule rewrite / firewall / Cloudflare không."
    elif grep -qE "$RE_EAB" <<<"$t"; then
        warn "CA yêu cầu EAB. Với ZeroSSL: lấy EAB Kid/HMAC tại app.zerossl.com/developer rồi nhập ở menu [9] → 5."
    elif grep -qiE "$RE_DNSPROB" <<<"$t"; then
        warn "Lỗi DNS — domain chưa phân giải được. Kiểm tra bản ghi A/AAAA."
    else
        warn "Chưa xác định được nguyên nhân. Xem chi tiết bằng lệnh:"
        printf '      %sgrep -iE '\''"detail"|acme:error|Retry-After'\'' %s | tail -20%s\n' "$CYN" "$LOG_FILE" "$NC"
    fi
}

#------------------------------------------------------------------------------
# Cài chứng chỉ vào panel / vhost (kèm đăng ký reloadcmd để auto-renew tự cài lại)
#------------------------------------------------------------------------------
deploy_cert() { # deploy_cert <domain chính>
    local d="$1"

    case "$PANEL" in
    #-------------------------------------------------- cPanel
    cpanel)
        if [ "$IS_ROOT" -eq 1 ]; then
            deploy_cpanel_root "$d"
        else
            info "Deploy qua cPanel UAPI hook..."
            if "$ACME" --deploy --deploy-hook cpanel_uapi -d "$d" --log "$LOG_FILE"; then
                ok "Đã cài SSL vào cPanel cho $d"
            else
                err "Deploy cPanel thất bại. Xem log: $LOG_FILE"; return 1
            fi
        fi
        ;;
    #-------------------------------------------------- DirectAdmin
    directadmin)
        deploy_directadmin "$d"
        ;;
    #-------------------------------------------------- CyberPanel
    cyberpanel)
        install_to_paths "$d" \
            "/etc/letsencrypt/live/$d/fullchain.pem" \
            "/etc/letsencrypt/live/$d/privkey.pem" \
            "" \
            "/usr/local/lsws/bin/lswsctrl restart"
        ;;
    #-------------------------------------------------- aaPanel
    aapanel)
        local cdir="/www/server/panel/vhost/cert/$d"
        mkdir -p "$cdir"
        install_to_paths "$d" "$cdir/fullchain.pem" "$cdir/privkey.pem" "" "$(reload_cmd)"
        parse_vhost "$d"
        if [ -n "$VHOST_CERT" ] && [ "$VHOST_CERT" != "$cdir/fullchain.pem" ]; then
            warn "vhost đang trỏ cert tới: $VHOST_CERT"
            if confirm "Cài thêm bản sao vào đúng đường dẫn vhost đang dùng?"; then
                install_to_paths "$d" "$VHOST_CERT" "${VHOST_KEY:-${VHOST_CERT%/*}/privkey.pem}" "" "$(reload_cmd)"
            fi
        elif [ -z "$VHOST_CERT" ]; then
            warn "vhost của $d chưa bật SSL."
            warn "Vào aaPanel → Website → $d → SSL → chọn 'Other Certificate' và Save một lần"
            warn "hoặc dùng menu [7] để chèn cấu hình SSL tự động."
        fi
        ;;
    #-------------------------------------------------- Plesk
    plesk)
        deploy_plesk "$d"
        ;;
    #-------------------------------------------------- Hestia
    hestia)
        deploy_hestia "$d"
        ;;
    #-------------------------------------------------- Không panel
    none|*)
        deploy_generic "$d"
        ;;
    esac
}

# --install-cert dùng chung: acme.sh sẽ nhớ và tự cài lại mỗi lần renew
install_to_paths() { # <domain> <fullchain> <key> <ca|""> <reloadcmd>
    local d="$1" fc="$2" key="$3" ca="$4" rl="$5"
    local -a o=(--install-cert -d "$d" --key-file "$key" --fullchain-file "$fc" --log "$LOG_FILE")
    [[ "$KEYLENGTH" == ec-* ]] && o+=(--ecc)
    [ -n "$ca" ] && o+=(--ca-file "$ca")
    [ -n "$rl" ] && o+=(--reloadcmd "$rl")

    mkdir -p "$(dirname "$fc")" "$(dirname "$key")" 2>/dev/null
    # Sao lưu cert cũ nếu có
    [ -f "$fc" ]  && cp -a "$fc"  "$fc.bak.$(date +%s)"  2>/dev/null
    [ -f "$key" ] && cp -a "$key" "$key.bak.$(date +%s)" 2>/dev/null

    if "$ACME" "${o[@]}"; then
        chmod 600 "$key" 2>/dev/null
        ok "Đã cài cert: $fc"
        ok "Đã cài key : $key"
        return 0
    fi
    err "Cài cert thất bại. Xem log: $LOG_FILE"
    return 1
}

#------------------------------------------------------------------------------
deploy_cpanel_root() {
    local d="$1" cdir
    cdir="$HOME/.acme.sh/$d"
    [[ "$KEYLENGTH" == ec-* ]] && cdir="$cdir"_ecc
    [ -d "$cdir" ] || cdir=$(dirname "$ACME")/"$d"

    local crt="$cdir/$d.cer" key="$cdir/$d.key" ca="$cdir/ca.cer"
    [ -f "$crt" ] || { err "Không tìm thấy cert tại $cdir"; return 1; }

    if command -v whmapi1 >/dev/null 2>&1; then
        info "Cài SSL qua WHM API (whmapi1 installssl)..."
        whmapi1 installssl domain="$d" \
            crt="$(cat "$crt")" key="$(cat "$key")" cabundle="$(cat "$ca" 2>/dev/null)" \
            >>"$LOG_FILE" 2>&1 \
            && ok "Đã cài SSL vào cPanel cho $d" \
            || { err "whmapi1 installssl thất bại. Xem log: $LOG_FILE"; return 1; }
    else
        err "Không tìm thấy whmapi1. Hãy chạy script bằng user cPanel sở hữu domain."
        return 1
    fi
}

deploy_directadmin() {
    local d="$1"
    [ "$IS_ROOT" -eq 1 ] || { err "DirectAdmin cần chạy bằng root"; return 1; }
    [ -n "$DOMAIN_USER" ] || { err "Không xác định được user sở hữu $d"; return 1; }

    local base="/usr/local/directadmin/data/users/$DOMAIN_USER/domains"
    local dom="$d"
    # Với subdomain, cert nằm ở file của domain cha
    if [ ! -f "$base/$d.conf" ]; then
        local b
        for b in $(cut -d' ' -f1 "/usr/local/directadmin/data/users/$DOMAIN_USER/domains.list"); do
            [[ "$d" == *".$b" ]] && { dom="$b"; break; }
        done
    fi

    info "Cài cert cho user '$DOMAIN_USER', domain '$dom'"
    install_to_paths "$d" "$base/$dom.cert" "$base/$dom.key" "$base/$dom.cacert" \
        "echo 'action=rewrite&value=httpd' >> /usr/local/directadmin/data/task.queue; /usr/local/directadmin/dataskq d2000" || return 1

    # Bật SSL cho domain trong config của DA
    if [ -f "$base/$dom.conf" ]; then
        if grep -q '^ssl=' "$base/$dom.conf"; then
            sed -i 's/^ssl=.*/ssl=ON/' "$base/$dom.conf"
        else
            echo "ssl=ON" >>"$base/$dom.conf"
        fi
        ok "Đã bật ssl=ON cho $dom"
    fi
    chown "diradmin:diradmin" "$base/$dom".{cert,key,cacert} 2>/dev/null
    echo 'action=rewrite&value=httpd' >>/usr/local/directadmin/data/task.queue
    /usr/local/directadmin/dataskq d2000 >>"$LOG_FILE" 2>&1
    ok "Đã đẩy task rewrite httpd cho DirectAdmin"
}

deploy_plesk() {
    local d="$1" cdir
    cdir="$HOME/.acme.sh/$d"; [[ "$KEYLENGTH" == ec-* ]] && cdir="${cdir}_ecc"
    if command -v plesk >/dev/null 2>&1 && [ -f "$cdir/$d.cer" ]; then
        info "Cài SSL qua Plesk CLI..."
        plesk bin certificate --create "acme-$d" -domain "$d" \
            -cert-file "$cdir/$d.cer" -key-file "$cdir/$d.key" -cacert-file "$cdir/ca.cer" \
            >>"$LOG_FILE" 2>&1
        plesk bin site --update "$d" -ssl true -certificate-name "acme-$d" >>"$LOG_FILE" 2>&1 \
            && ok "Đã cài SSL vào Plesk cho $d" \
            || { warn "Plesk CLI lỗi, chuyển sang cài trực tiếp vào vhost"; deploy_generic "$d"; }
    else
        deploy_generic "$d"
    fi
}

deploy_hestia() {
    local d="$1" u="${DOMAIN_USER:-}"
    if [ -n "$u" ] && [ -d "/home/$u/conf/web/$d" ]; then
        install_to_paths "$d" \
            "/home/$u/conf/web/$d/ssl/$d.pem" \
            "/home/$u/conf/web/$d/ssl/$d.key" \
            "/home/$u/conf/web/$d/ssl/$d.ca" \
            "$(reload_cmd)"
    else
        deploy_generic "$d"
    fi
}

# VPS không panel: ưu tiên ghi đè đúng path vhost đang khai báo
deploy_generic() {
    local d="$1"
    parse_vhost "$d"

    local fc key
    if [ -n "$VHOST_CERT" ] && [ -n "$VHOST_KEY" ]; then
        ok "Phát hiện vhost: ${VHOST_FILE:-<inline>}"
        info "  ssl_certificate     → $VHOST_CERT"
        info "  ssl_certificate_key → $VHOST_KEY"
        if confirm "Ghi chứng chỉ mới vào đúng 2 đường dẫn này?"; then
            fc="$VHOST_CERT"; key="$VHOST_KEY"
        fi
    fi

    if [ -z "$fc" ]; then
        fc="$CERT_STORE/$d/fullchain.pem"
        key="$CERT_STORE/$d/privkey.pem"
        info "Sẽ lưu chứng chỉ tại: $CERT_STORE/$d/"
    fi

    install_to_paths "$d" "$fc" "$key" "" "$(reload_cmd)" || return 1

    if [ -z "$VHOST_CERT" ]; then
        warn "vhost của $d chưa khai báo SSL. Thêm vào cấu hình web server:"
        case "$WEBSERVER" in
            nginx)
                cat <<EOF

${CYN}listen 443 ssl;
ssl_certificate     $fc;
ssl_certificate_key $key;${NC}
EOF
                ;;
            apache)
                cat <<EOF

${CYN}SSLEngine on
SSLCertificateFile    $fc
SSLCertificateKeyFile $key${NC}
EOF
                ;;
            openlitespeed)
                cat <<EOF

${CYN}vhssl {
  keyFile   $key
  certFile  $fc
  certChain 1
}${NC}
EOF
                ;;
        esac
        printf '\n'
        if [ "$WEBSERVER" = "nginx" ] && [ -n "$VHOST_FILE" ]; then
            confirm "Tự động chèn block SSL vào $VHOST_FILE (có backup)?" && \
                inject_nginx_ssl "$d" "$VHOST_FILE" "$fc" "$key"
        fi
    fi
}

inject_nginx_ssl() {
    local d="$1" f="$2" fc="$3" key="$4" bak
    bak="$f.bak.$(date +%s)"
    cp -a "$f" "$bak" || { err "Không tạo được backup"; return 1; }
    ok "Đã backup: $bak"

    cat >>"$f" <<EOF

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $d www.$d;
    root $DOCROOT;
    index index.php index.html index.htm;

    ssl_certificate     $fc;
    ssl_certificate_key $key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_session_cache   shared:SSL:10m;

    location / { try_files \$uri \$uri/ /index.php?\$args; }
}
EOF
    if nginx -t >>"$LOG_FILE" 2>&1; then
        do_reload
        ok "Đã chèn block SSL vào $f"
    else
        err "Cấu hình nginx lỗi — đã khôi phục bản backup"
        cp -a "$bak" "$f"
        nginx -t
        return 1
    fi
}

#------------------------------------------------------------------------------
# Luồng chính: cài SSL cho 1 domain
#------------------------------------------------------------------------------
run_install() { # run_install <domain> [thêm_www:1/0] [im lặng:1/0]
    local d="$1" with_www="${2:-1}" quiet="${3:-0}"
    local -a extra=()

    d="$(normalize_domain "$d")"
    valid_domain "$d" || { err "Domain không hợp lệ: $d"; return 1; }

    title "===== Xử lý: $d ====="

    if ! find_docroot "$d"; then
        warn "Không tự tìm được DocumentRoot cho $d"
        [ "$quiet" -eq 1 ] && { err "Bỏ qua $d"; return 1; }
        ask DOCROOT "Nhập DocumentRoot thủ công" "$DOCROOT"
        [ -d "$DOCROOT" ] || { err "Thư mục không tồn tại: $DOCROOT"; return 1; }
    fi
    ok "DocumentRoot: $DOCROOT"
    [ -n "$DOMAIN_USER" ] && info "User sở hữu: $DOMAIN_USER"

    # www chỉ thêm khi không phải subdomain
    if [ "$with_www" -eq 1 ] && ! is_subdomain "$d"; then
        if resolves_to_this_server "www.$d"; then
            extra+=("www.$d")
            info "Sẽ cấp kèm: www.$d"
        else
            warn "www.$d chưa trỏ về server này → bỏ qua để tránh lỗi xác thực"
        fi
    fi

    if [ "$ISSUE_METHOD" = "webroot" ] && ! precheck_webroot "$d"; then
        if [ "$quiet" -eq 1 ]; then
            err "Bỏ qua $d — precheck thất bại"; return 1
        fi
        confirm "Vẫn tiếp tục gọi CA?" || return 1
    fi

    issue_cert "$d" "${extra[@]}" || return 1
    deploy_cert "$d" || return 1
    do_reload

    title "Kết quả cho $d"
    show_cert_info "$d"
    log "Cài SSL thành công: $d"
}

resolves_to_this_server() {
    local host="$1" ips myip
    command -v dig >/dev/null 2>&1 || command -v host >/dev/null 2>&1 || return 0  # không kiểm tra được thì cho qua
    if command -v dig >/dev/null 2>&1; then
        ips=$(dig +short A "$host" 2>/dev/null)
    else
        ips=$(host -t A "$host" 2>/dev/null | awk '/has address/{print $NF}')
    fi
    [ -z "$ips" ] && return 1
    myip=$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null)
    [ -z "$myip" ] && return 0
    grep -qx "$myip" <<<"$ips"
}

show_cert_info() {
    local d="$1" f
    for f in "$HOME/.acme.sh/$d/$d.cer" "$HOME/.acme.sh/${d}_ecc/$d.cer"; do
        [ -f "$f" ] || continue
        printf '  CA     : %s%s%s\n' "$GRN" "$(ca_label "$(cert_current_ca "$d")")" "$NC"
        printf '  Issuer : %s\n' "$(openssl x509 -in "$f" -noout -issuer 2>/dev/null | sed 's/.*CN[[:space:]]*=[[:space:]]*//')"
        printf '  SAN    : %s\n' "$(openssl x509 -in "$f" -noout -ext subjectAltName 2>/dev/null | tail -1 | sed 's/DNS://g; s/^[[:space:]]*//')"
        printf '  Hết hạn: %s\n' "$(openssl x509 -in "$f" -noout -enddate 2>/dev/null | cut -d= -f2)"
        return 0
    done
    warn "Chưa tìm thấy file chứng chỉ của $d trong ~/.acme.sh"
}

#------------------------------------------------------------------------------
# Các mục menu
#------------------------------------------------------------------------------
# Số thứ tự tương ứng CA đang chọn, dùng làm giá trị mặc định khi hỏi
ca_default_choice() {
    case "$CA_SERVER" in
        letsencrypt) echo 1 ;; zerossl) echo 2 ;;
        buypass)     echo 3 ;; *)       echo 4 ;;
    esac
}

# Hỏi nhà cung cấp chứng chỉ ngay trước khi cài
choose_ca_inline() {
    title "Chọn nhà cung cấp chứng chỉ"
    cat <<EOF
  ${BLD}1)${NC} Let's Encrypt   — 90 ngày, giới hạn 5 cert trùng tên/tuần
  ${BLD}2)${NC} ZeroSSL         — 90 ngày, cần EAB (acme.sh tự lấy qua email)
  ${BLD}3)${NC} Buypass         — 180 ngày, không hỗ trợ wildcard
  ${BLD}4)${NC} Auto            — thử Let's Encrypt, rate limit thì chuyển ZeroSSL
EOF
    local c; ask c "Chọn" "$(ca_default_choice)"
    case "$c" in
        1) CA_SERVER="letsencrypt" ;;
        2) CA_SERVER="zerossl" ;;
        3) CA_SERVER="buypass" ;;
        4) CA_SERVER="auto" ;;
        *) warn "Lựa chọn không hợp lệ, giữ nguyên $(ca_label "$CA_SERVER")" ;;
    esac
    ok "Sẽ cấp bằng: $(ca_label "$CA_SERVER")"
    [ "$CA_SERVER" = "buypass" ] && warn "Buypass không cấp wildcard."
    return 0
}

# Domain đã có cert: quyết định có ép cấp lại hay không
FORCE_ISSUE=0
maybe_confirm_reissue() {
    local d="$1" cur days want
    FORCE_ISSUE=0
    cert_exists "$d" || return 0

    cur="$(cert_current_ca "$d")"
    days="$(cert_days_left "$d")"
    want="$CA_SERVER"; [ "$want" = "auto" ] && want="letsencrypt"

    if [ -n "$cur" ] && [ "$cur" != "$want" ]; then
        info "Cert hiện tại: $(ca_label "$cur")${days:+ (còn $days ngày)}"
        ok  "Sẽ ép cấp lại bằng $(ca_label "$want")"
        FORCE_ISSUE=1
        return 0
    fi

    warn "Domain đã có cert của $(ca_label "${cur:-không rõ}")${days:+, còn $days ngày}."
    if confirm "Cấp lại ngay bây giờ (--force)?"; then
        FORCE_ISSUE=1
    else
        info "Giữ nguyên cert hiện tại, chỉ cài lại vào web server."
    fi
    return 0
}

menu_single() {
    local d www
    choose_ca_inline
    printf '\n'
    ask d "Nhập domain cần cài SSL"
    [ -n "$d" ] || return
    d="$(normalize_domain "$d")"
    maybe_confirm_reissue "$d"
    www=1
    is_subdomain "$d" && www=0
    run_install "$d" "$www"
    FORCE_ISSUE=0
}

menu_multi() {
    local input d list
    choose_ca_inline
    printf '\n'
    info "Nhập nhiều domain, cách nhau bởi dấu cách hoặc dấu phẩy."
    ask input "Danh sách domain"
    [ -n "$input" ] || return
    list=$(tr ',' ' ' <<<"$input")
    FORCE_ISSUE=0
    confirm "Ép cấp lại (--force) với domain đã có cert còn hạn?" && FORCE_ISSUE=1
    local total=0 okc=0
    for d in $list; do
        total=$((total+1))
        run_install "$d" 1 1 && okc=$((okc+1))
    done
    FORCE_ISSUE=0
    title "Hoàn tất: $okc/$total domain thành công"
}

menu_san() {
    local main input d
    choose_ca_inline
    printf '\n'
    info "Cấp 1 chứng chỉ duy nhất cho nhiều domain (SAN/UCC)."
    ask main "Domain chính (dùng làm tên chứng chỉ)"
    ask input "Các domain phụ (cách nhau bởi dấu cách)"
    main="$(normalize_domain "$main")"
    valid_domain "$main" || { err "Domain không hợp lệ"; return 1; }
    maybe_confirm_reissue "$main"
    find_docroot "$main" || { ask DOCROOT "Nhập DocumentRoot"; }
    ok "DocumentRoot: $DOCROOT"

    local -a extra=()
    for d in $(tr ',' ' ' <<<"$input"); do
        d="$(normalize_domain "$d")"
        valid_domain "$d" && extra+=("$d")
    done
    issue_cert "$main" "${extra[@]}" && deploy_cert "$main" && do_reload
    FORCE_ISSUE=0
    show_cert_info "$main"
}

menu_wildcard() {
    local d
    choose_ca_inline
    if [ "$CA_SERVER" = "buypass" ]; then
        err "Buypass không cấp chứng chỉ wildcard. Hãy chọn CA khác."
        return 1
    fi
    printf '\n'
    info "Wildcard (*.domain.com) bắt buộc xác thực DNS-01."
    ask d "Domain gốc (vd: azdigi.com)"
    d="$(normalize_domain "$d")"
    valid_domain "$d" || { err "Domain không hợp lệ"; return 1; }
    maybe_confirm_reissue "$d"

    printf '\n%s1)%s Cloudflare API (dns_cf)\n' "$BLD" "$NC"
    printf '%s2)%s DNS thủ công (tự thêm bản ghi TXT)\n' "$BLD" "$NC"
    local c; ask c "Chọn" "1"

    ISSUE_METHOD="dns"
    if [ "$c" = "1" ]; then
        DNS_API="dns_cf"
        if [ -z "$CF_Token" ] && [ -z "$CF_Key" ]; then
            ask CF_Token "Cloudflare API Token"
            ask CF_Account_ID "Cloudflare Account ID (Enter để bỏ qua)"
            export CF_Token CF_Account_ID
        fi
    else
        DNS_API=""
    fi

    find_docroot "$d" >/dev/null 2>&1
    issue_cert "$d" "*.$d" && deploy_cert "$d" && do_reload
    ISSUE_METHOD="webroot"; DNS_API=""; FORCE_ISSUE=0
    show_cert_info "$d"
}

menu_list() {
    title "Chứng chỉ do acme.sh quản lý"
    "$ACME" --list 2>/dev/null || warn "Chưa có chứng chỉ nào"
    printf '\n'
    local d
    for d in $("$ACME" --list 2>/dev/null | awk 'NR>1 {print $1}'); do
        printf '%s%s%s\n' "$BLD" "$d" "$NC"
        show_cert_info "$d"
        printf '\n'
    done
}

menu_renew() {
    local d
    ask d "Domain cần gia hạn (Enter = gia hạn tất cả)"
    if [ -z "$d" ]; then
        info "Đang gia hạn toàn bộ chứng chỉ..."
        "$ACME" --cron --force --log "$LOG_FILE"
    else
        d="$(normalize_domain "$d")"
        info "Đang gia hạn $d..."
        "$ACME" --renew -d "$d" --force --log "$LOG_FILE" \
            || "$ACME" --renew -d "$d" --ecc --force --log "$LOG_FILE"
        deploy_cert "$d"
    fi
    do_reload
    ok "Hoàn tất gia hạn"
}

menu_cron() {
    title "Trạng thái tự động gia hạn"
    if crontab -l 2>/dev/null | grep -q 'acme.sh'; then
        ok "Cron auto-renew đã được thiết lập:"
        crontab -l 2>/dev/null | grep 'acme.sh'
    else
        warn "Chưa có cron auto-renew"
        if confirm "Cài đặt cron tự động gia hạn ngay?"; then
            "$ACME" --install-cronjob >>"$LOG_FILE" 2>&1 && ok "Đã cài cron" || err "Cài cron thất bại"
        fi
    fi
    printf '\n'
    info "acme.sh tự cài lại cert vào đúng vị trí mỗi lần gia hạn (nhờ --install-cert / deploy-hook)."
}

registered_cas() {
    local out="" ca dir
    for ca in letsencrypt zerossl buypass; do
        case "$ca" in
            letsencrypt) dir="$HOME/.acme.sh/ca/acme-v02.api.letsencrypt.org" ;;
            zerossl)     dir="$HOME/.acme.sh/ca/acme.zerossl.com" ;;
            buypass)     dir="$HOME/.acme.sh/ca/api.buypass.com" ;;
        esac
        if find "$dir" -name 'account.key' 2>/dev/null | grep -q .; then
            out="$out$(ca_label "$ca"), "
        fi
    done
    printf '%s' "${out%, }"
    [ -z "$out" ] && printf 'chưa có'
}

menu_info() {
    title "Thông tin hệ thống"
    printf '  Panel       : %s\n'  "$PANEL_NAME ($PANEL)"
    printf '  Web server  : %s%s\n' "$WEBSERVER" "${WEBSERVER_SVC:+ (service: $WEBSERVER_SVC)}"
    printf '  Quyền chạy  : %s\n'  "$([ "$IS_ROOT" -eq 1 ] && echo 'root' || echo "user $(whoami)")"
    printf '  acme.sh     : %s\n'  "${ACME:-chưa cài}"
    printf '  CA đang dùng: %s\n'  "$(ca_label "$CA_SERVER")"
    printf '  Account đã ĐK: %s\n' "$(registered_cas)"
    printf '  Key length  : %s\n'  "$KEYLENGTH"
    printf '  Email       : %s\n'  "$ACME_EMAIL"
    printf '  Log         : %s\n'  "$LOG_FILE"
    printf '  IP công cộng: %s\n'  "$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || echo 'không xác định')"

    local d
    ask d "Kiểm tra vhost của domain (Enter để bỏ qua)"
    [ -n "$d" ] || return
    d="$(normalize_domain "$d")"
    find_docroot "$d" >/dev/null 2>&1
    parse_vhost "$d"
    printf '\n'
    printf '  DocumentRoot: %s\n' "${DOCROOT:-không tìm thấy}"
    printf '  Vhost file  : %s\n' "${VHOST_FILE:-không tìm thấy}"
    printf '  Cert path   : %s\n' "${VHOST_CERT:-chưa khai báo}"
    printf '  Key path    : %s\n' "${VHOST_KEY:-chưa khai báo}"
    [ -n "$DOMAIN_USER" ] && printf '  Owner       : %s\n' "$DOMAIN_USER"
}

menu_ca() {
    title "Chọn nhà cung cấp chứng chỉ"
    cat <<EOF
  ${BLD}1)${NC} Auto            — thử Let's Encrypt, dính rate limit thì tự chuyển ZeroSSL ${GRN}(khuyến nghị)${NC}
  ${BLD}2)${NC} Let's Encrypt   — 90 ngày, giới hạn 5 cert trùng tên/tuần
  ${BLD}3)${NC} ZeroSSL         — 90 ngày, cần đăng ký EAB (acme.sh tự lấy qua email)
  ${BLD}4)${NC} Buypass         — 180 ngày, không hỗ trợ wildcard
  ${BLD}5)${NC} Nhập EAB của ZeroSSL thủ công
  ${BLD}0)${NC} Quay lại

  Đang dùng: ${YLW}$(ca_label "$CA_SERVER")${NC}
EOF
    local c; ask c "Chọn"
    case "$c" in
        1) CA_SERVER="auto" ;;
        2) CA_SERVER="letsencrypt" ;;
        3) CA_SERVER="zerossl" ;;
        4) CA_SERVER="buypass" ;;
        5) info "Lấy tại: https://app.zerossl.com/developer"
           ask ZEROSSL_EAB_KID  "EAB KID"  "$ZEROSSL_EAB_KID"
           ask ZEROSSL_EAB_HMAC "EAB HMAC" "$ZEROSSL_EAB_HMAC"
           register_ca zerossl && ok "Đã lưu EAB cho ZeroSSL"
           return ;;
        *) return ;;
    esac
    local def="$CA_SERVER"; [ "$def" = "auto" ] && def="letsencrypt"
    "$ACME" --set-default-ca --server "$def" >>"$LOG_FILE" 2>&1
    register_ca "$def"
    ok "CA hiện tại: $(ca_label "$CA_SERVER")"
    [ "$CA_SERVER" = "buypass" ] && warn "Buypass không cấp wildcard và yêu cầu email hợp lệ."
}

menu_settings() {
    title "Cấu hình"
    printf '  1) Nhà cung cấp chứng chỉ : %s\n' "$(ca_label "$CA_SERVER")"
    printf '  2) Email đăng ký          : %s\n' "$ACME_EMAIL"
    printf '  3) Độ dài khoá            : %s\n' "$KEYLENGTH"
    printf '  4) Cách xác thực          : %s\n' "$ISSUE_METHOD"
    printf '  5) Ghi đè panel/webserver\n'
    printf '  0) Quay lại\n'
    local c; ask c "Chọn"
    case "$c" in
        1) menu_ca ;;
        2) ask ACME_EMAIL "Email mới" "$ACME_EMAIL"
           local def="$CA_SERVER"; [ "$def" = "auto" ] && def="letsencrypt"
           register_ca "$def"; ok "Đã cập nhật" ;;
        3) info "2048 | 4096 | ec-256 | ec-384"
           ask KEYLENGTH "Độ dài khoá" "$KEYLENGTH"; ok "Đã cập nhật" ;;
        4) info "webroot (khuyến nghị) | standalone (dừng web server) | dns"
           ask ISSUE_METHOD "Cách xác thực" "$ISSUE_METHOD"; ok "Đã cập nhật" ;;
        5) ask PANEL "Panel (cpanel/directadmin/aapanel/cyberpanel/plesk/hestia/none)" "$PANEL"
           ask WEBSERVER "Web server (nginx/apache/openlitespeed)" "$WEBSERVER"
           ask WEBSERVER_SVC "Tên service" "$WEBSERVER_SVC"
           PANEL_NAME="$PANEL (thủ công)"; ok "Đã cập nhật" ;;
    esac
}

menu_remove() {
    local d
    ask d "Domain cần gỡ khỏi acme.sh"
    [ -n "$d" ] || return
    d="$(normalize_domain "$d")"
    warn "Thao tác này chỉ gỡ khỏi acme.sh (dừng auto-renew), KHÔNG xoá cert đang chạy trên web server."
    confirm "Xác nhận gỡ $d?" || return
    "$ACME" --remove -d "$d" --log "$LOG_FILE" || "$ACME" --remove -d "$d" --ecc --log "$LOG_FILE"
    ok "Đã gỡ $d"
}

#------------------------------------------------------------------------------
# Menu chính
#------------------------------------------------------------------------------
banner() {
    clear 2>/dev/null
    printf '%s' "$CYN"
    cat <<'EOF'
 ╔══════════════════════════════════════════════════════════╗
 ║          AZDIGI UNIVERSAL SSL MANAGER                    ║
 ║   CA   : Let's Encrypt · ZeroSSL · Buypass               ║
 ║   Panel: cPanel · DirectAdmin · aaPanel · CyberPanel     ║
 ║          Plesk · Hestia · VPS không panel                ║
 ╚══════════════════════════════════════════════════════════╝
EOF
    printf '%s' "$NC"
    printf ' Panel: %s%s%s  |  Web: %s%s%s  |  Quyền: %s%s%s\n' \
        "$GRN" "$PANEL_NAME" "$NC" \
        "$GRN" "$WEBSERVER" "$NC" \
        "$GRN" "$([ "$IS_ROOT" -eq 1 ] && echo root || whoami)" "$NC"
    printf ' CA   : %s%s%s  |  Key: %s%s%s  |  v%s\n\n' \
        "$YLW" "$(ca_label "$CA_SERVER")" "$NC" \
        "$GRN" "$KEYLENGTH" "$NC" "$VERSION"
}

main_menu() {
    while true; do
        banner
        cat <<EOF
  ${BLD}1)${NC} Cài SSL cho 1 domain          (tự phát hiện docroot & vhost)
  ${BLD}2)${NC} Cài SSL hàng loạt             (nhiều domain một lượt)
  ${BLD}3)${NC} Cài SSL đa domain 1 cert      (SAN / UCC)
  ${BLD}4)${NC} Cài SSL Wildcard              (*.domain — qua DNS-01)
  ${BLD}5)${NC} Xem chứng chỉ & hạn sử dụng
  ${BLD}6)${NC} Gia hạn ngay
  ${BLD}7)${NC} Kiểm tra / cài cron auto-renew
  ${BLD}8)${NC} Thông tin hệ thống & kiểm tra vhost
  ${BLD}9)${NC} Đổi nhà cung cấp chứng chỉ    (Let's Encrypt / ZeroSSL / Auto)
  ${BLD}10)${NC} Cấu hình khác                (email, key, phương thức xác thực)
  ${BLD}11)${NC} Gỡ domain khỏi acme.sh
  ${BLD}0)${NC} Thoát

EOF
        local c
        if ! read -r -p "Chọn chức năng: " c; then
            printf '\n'
            err "Không đọc được input (stdin đã đóng)."
            err "Nếu chạy qua pipe, hãy tải file về rồi chạy: bash ssl-manager.sh"
            exit 1
        fi
        case "$c" in
            1)  menu_single;   pause ;;
            2)  menu_multi;    pause ;;
            3)  menu_san;      pause ;;
            4)  menu_wildcard; pause ;;
            5)  menu_list;     pause ;;
            6)  menu_renew;    pause ;;
            7)  menu_cron;     pause ;;
            8)  menu_info;     pause ;;
            9)  menu_ca;       pause ;;
            10) menu_settings; pause ;;
            11) menu_remove;   pause ;;
            0)  printf '\nTạm biệt!\n'; exit 0 ;;
            *)  err "Lựa chọn không hợp lệ"; sleep 1 ;;
        esac
    done
}

#------------------------------------------------------------------------------
# CLI không tương tác:  ./ssl-manager.sh install domain.com [domain2 ...]
#------------------------------------------------------------------------------
usage() {
    cat <<EOF
AZDIGI Universal SSL Manager v$VERSION

Dùng menu tương tác:
    bash $0

Dùng dòng lệnh:
    bash $0 install <domain> [domain2 ...]   Cài SSL cho một hoặc nhiều domain
    bash $0 renew   [domain]                 Gia hạn (bỏ trống = tất cả)
    bash $0 list                             Liệt kê chứng chỉ
    bash $0 info                             Thông tin hệ thống

Biến môi trường:
    ACME_EMAIL=...        Email đăng ký (mặc định: $ACME_EMAIL)
    KEYLENGTH=...         2048 | 4096 | ec-256 (mặc định: $KEYLENGTH)
    CA_SERVER=...         auto | letsencrypt | zerossl | buypass (mặc định: $CA_SERVER)
                          auto = thử Let's Encrypt trước, rate limit thì chuyển ZeroSSL
    ZEROSSL_EAB_KID=...   EAB của ZeroSSL (bỏ trống thì acme.sh tự lấy bằng email)
    ZEROSSL_EAB_HMAC=...

Ví dụ:
    CA_SERVER=zerossl bash $0 install azdigi.com
    CA_SERVER=letsencrypt KEYLENGTH=ec-256 bash $0 install azdigi.com
EOF
}

#------------------------------------------------------------------------------
main() {
    if [ -z "${BASH_VERSINFO[0]}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
        err "Script cần bash >= 4.0 (đang dùng ${BASH_VERSION:-sh}). Chạy: bash $0"
        exit 1
    fi
    detect_privileges
    detect_panel
    detect_webserver

    case "${1:-}" in
        -h|--help|help) usage; exit 0 ;;
    esac

    install_acme || exit 1

    case "${1:-}" in
        install)
            shift
            [ $# -gt 0 ] || { err "Thiếu domain"; usage; exit 1; }
            local rc=0
            for d in "$@"; do run_install "$d" 1 1 || rc=1; done
            exit $rc ;;
        renew)  shift; if [ -n "${1:-}" ]; then
                    "$ACME" --renew -d "$1" --force --log "$LOG_FILE" || \
                    "$ACME" --renew -d "$1" --ecc --force --log "$LOG_FILE"
                    deploy_cert "$1"
                else
                    "$ACME" --cron --log "$LOG_FILE"
                fi
                do_reload; exit 0 ;;
        list)   menu_list; exit 0 ;;
        info)   menu_info </dev/null; exit 0 ;;
        "")     main_menu ;;
        *)      err "Lệnh không hợp lệ: $1"; usage; exit 1 ;;
    esac
}

main "$@"
