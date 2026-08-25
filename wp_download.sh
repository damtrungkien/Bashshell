#!/bin/bash
#
# wp_download.sh - Tải & giải nén WordPress Core (Full hoặc No Content)
# Hỗ trợ: chọn từ danh sách bản mới nhất, nhập phiên bản thủ công, tải bản mới nhất.
#

set -uo pipefail

# ------------------------- Màu sắc -------------------------
if [[ -t 1 ]]; then
    C_RESET='\033[0m'; C_BOLD='\033[1m'
    C_GREEN='\033[0;32m'; C_RED='\033[0;31m'
    C_YEL='\033[0;33m'; C_CYAN='\033[0;36m'
else
    C_RESET=''; C_BOLD=''; C_GREEN=''; C_RED=''; C_YEL=''; C_CYAN=''
fi

info()  { echo -e "${C_CYAN}$*${C_RESET}"; }
ok()    { echo -e "${C_GREEN}$*${C_RESET}"; }
warn()  { echo -e "${C_YEL}$*${C_RESET}"; }
err()   { echo -e "${C_RED}$*${C_RESET}"; }
line()  { echo "======================================="; }

# ------------------------- Kiểm tra dependency -------------------------
command -v curl >/dev/null 2>&1 || { err "❌ Thiếu 'curl'. Vui lòng cài đặt trước."; exit 1; }
command -v unzip >/dev/null 2>&1 || { err "❌ Thiếu 'unzip'. Vui lòng cài đặt trước."; exit 1; }

# Chọn công cụ tải: ưu tiên wget, fallback sang curl
if command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
else
    DOWNLOADER="curl"
    warn "ℹ️  Không tìm thấy 'wget', sẽ dùng 'curl' để tải."
fi

# ------------------------- Lấy danh sách phiên bản -------------------------
line
echo -e "${C_BOLD}  Download & Extract WordPress (Full / No Content)${C_RESET}"
line

info "⏳ Đang lấy danh sách phiên bản từ api.wordpress.org ..."
# Portable: dùng grep -oE (chạy cả trên macOS/BSD lẫn Linux)
versions=$(curl -s https://api.wordpress.org/core/version-check/1.7/ \
    | grep -oE '"version":"[^"]+"' \
    | sed -E 's/"version":"//; s/"//' \
    | awk '!seen[$0]++' \
    | head -n 10)

if [[ -z "$versions" ]]; then
    warn "⚠️  Không lấy được danh sách phiên bản (có thể do mạng). Vẫn có thể nhập thủ công hoặc tải bản mới nhất."
fi

# ------------------------- Hàm chọn loại (wp-content) -------------------------
# $1 = phiên bản ("" nghĩa là bản mới nhất qua latest.zip)
# Set biến toàn cục: url, file_name
choose_type() {
    local version="$1"
    while true; do
        echo
        echo "Chọn loại tải xuống:"
        echo "  1 - Full (CÓ wp-content: themes/plugins mặc định)"
        echo "  2 - No Content (KHÔNG wp-content)"
        echo "  0 - Quay lại"
        read -r -p "Nhập lựa chọn [1/2/0]: " type

        case "$type" in
            1)
                if [[ -z "$version" ]]; then
                    url="https://wordpress.org/latest.zip"
                    file_name="wordpress-latest.zip"
                else
                    url="https://downloads.wordpress.org/release/wordpress-${version}.zip"
                    file_name="wordpress-${version}.zip"
                fi
                return 0
                ;;
            2)
                if [[ -z "$version" ]]; then
                    url="https://wordpress.org/latest-no-content.zip"
                    file_name="wordpress-latest-no-content.zip"
                else
                    url="https://downloads.wordpress.org/release/wordpress-${version}-no-content.zip"
                    file_name="wordpress-${version}-no-content.zip"
                fi
                return 0
                ;;
            0)
                return 1
                ;;
            *)
                err "❌ Lựa chọn không hợp lệ! Vui lòng chọn 1, 2 hoặc 0."
                ;;
        esac
    done
}

# ------------------------- Hàm kiểm tra URL tồn tại -------------------------
url_exists() {
    curl -sfI -o /dev/null "$1"
}

# ------------------------- Hàm tải + giải nén -------------------------
download_and_extract() {
    # Kiểm tra file trên server có tồn tại không
    info "🔎 Đang kiểm tra: $url"
    if ! url_exists "$url"; then
        err "❌ Không tìm thấy file trên server. Phiên bản có thể không tồn tại hoặc không có bản 'No Content' cho version này."
        return 1
    fi

    info "🔽 Đang tải về: $file_name ..."
    if [[ "$DOWNLOADER" == "wget" ]]; then
        wget -c "$url" -O "$file_name"
    else
        curl -L --fail -o "$file_name" "$url"
    fi

    if [[ $? -ne 0 ]]; then
        err "❌ Lỗi! Không thể tải về. Kiểm tra lại mạng hoặc phiên bản."
        return 1
    fi
    ok "✅ Tải về thành công: $file_name"

    # Cảnh báo nếu thư mục wordpress đã tồn tại
    if [[ -d "wordpress" ]]; then
        warn "⚠️  Thư mục 'wordpress/' đã tồn tại. Giải nén sẽ ghi đè các file trùng tên."
        read -r -p "Tiếp tục? [y/N]: " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || { warn "Đã hủy giải nén. File zip vẫn giữ tại: $file_name"; return 1; }
    fi

    info "📂 Đang giải nén: $file_name ..."
    if unzip -o "$file_name" -d . >/dev/null; then
        ok "✅ Giải nén thành công vào: $(pwd)/wordpress"
    else
        err "❌ Lỗi! Không thể giải nén file $file_name."
        return 1
    fi

    # Hỏi giữ hay xóa file zip
    read -r -p "Xóa file zip '$file_name' sau khi giải nén? [y/N]: " del
    if [[ "$del" =~ ^[Yy]$ ]]; then
        rm -f "$file_name" && ok "🗑️  Đã xóa $file_name"
    else
        info "📦 Giữ lại file zip: $file_name"
    fi
    return 0
}

# ------------------------- Menu chính -------------------------
while true; do
    echo
    line
    if [[ -n "$versions" ]]; then
        info "📌 10 phiên bản WordPress mới nhất:"
        echo "$versions" | tr '\n' ' '; echo
        line
    fi
    echo -e "${C_BOLD}MENU CHÍNH${C_RESET}"
    echo "  1 - Chọn từ danh sách bản mới nhất"
    echo "  2 - Nhập phiên bản thủ công (mọi phiên bản)"
    echo "  3 - Tải bản mới nhất (latest)"
    echo "  0 - Thoát"
    read -r -p "Nhập lựa chọn: " choice

    case "$choice" in
        1)
            if [[ -z "$versions" ]]; then
                err "❌ Không có danh sách phiên bản. Hãy dùng tùy chọn 2 (nhập thủ công)."
                continue
            fi
            read -r -p "Nhập phiên bản trong danh sách trên: " version
            if ! echo "$versions" | grep -qx "$version"; then
                err "❌ Phiên bản '$version' không có trong danh sách. Nếu muốn tải bản cũ hơn, dùng tùy chọn 2."
                continue
            fi
            choose_type "$version" && download_and_extract
            ;;
        2)
            read -r -p "Nhập phiên bản WordPress (vd: 6.4.3, 5.9, ...): " version
            if [[ -z "$version" ]]; then
                err "❌ Bạn chưa nhập phiên bản."
                continue
            fi
            # Kiểm tra định dạng phiên bản cơ bản (số và dấu chấm)
            if ! [[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
                err "❌ Định dạng phiên bản không hợp lệ (chỉ gồm số và dấu chấm)."
                continue
            fi
            choose_type "$version" && download_and_extract
            ;;
        3)
            choose_type "" && download_and_extract
            ;;
        0)
            info "👋 Thoát. Tạm biệt!"
            exit 0
            ;;
        *)
            err "❌ Lựa chọn không hợp lệ!"
            ;;
    esac
done
