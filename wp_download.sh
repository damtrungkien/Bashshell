#!/bin/bash

echo "======================================="
echo "  Download and Extract WordPress Full or No Content"
echo "======================================="

# Lấy danh sách 10 phiên bản mới nhất từ API WordPress
versions=$(curl -s https://api.wordpress.org/core/version-check/1.7/ | grep -oP '(?<="version":")[^"]+' | head -n 10)

echo "📌 10 phiên bản WordPress mới nhất có sẵn:"
echo "$versions" | tr ' ' '\n'
echo "======================================="

# Nhập phiên bản và loại tải từ người dùng
while true; do
    read -p "Nhập phiên bản WordPress muốn tải (Enter để tải bản mới nhất): " version
    echo "Chọn loại:"
    echo "  1 - Full"
    echo "  2 - No Content"
    read -p "Nhập lựa chọn [1/2]: " type

    if [[ -z "$version" ]]; then
        url="https://wordpress.org/latest.zip"
        file_name="wordpress-latest.zip"
        echo "📌 Không nhập phiên bản. Mặc định tải về bản mới nhất (Full)!"
        break
    elif echo "$versions" | grep -q "^$version$"; then
        if [[ "$type" == "1" ]]; then
            url="https://downloads.wordpress.org/release/wordpress-${version}.zip"
            file_name="wordpress-${version}.zip"
            break
        elif [[ "$type" == "2" ]]; then
            url="https://downloads.wordpress.org/release/wordpress-${version}-no-content.zip"
            file_name="wordpress-${version}-no-content.zip"
            break
        else
            echo "❌ Loại không hợp lệ! Vui lòng chọn 1 (Full) hoặc 2 (No Content)."
        fi
    else
        echo "❌ Phiên bản không hợp lệ! Vui lòng nhập lại một trong các phiên bản có sẵn."
    fi
done

# Xác nhận tải xuống
echo "🔽 Đang tải về: $url ..."
wget -c "$url" -O "$file_name"

# Kiểm tra tải xuống có thành công không
if [[ $? -eq 0 ]]; then
    echo "✅ Tải về thành công: $file_name"
    
    # Giải nén file
    echo "📂 Đang giải nén: $file_name ..."
    unzip -o "$file_name" -d .
    
    # Kiểm tra giải nén có thành công không
    if [[ $? -eq 0 ]]; then
        echo "✅ Giải nén thành công!"
    else
        echo "❌ Lỗi! Không thể giải nén file. Vui lòng kiểm tra file $file_name."
    fi
else
    echo "❌ Lỗi! Không thể tải về. Vui lòng kiểm tra lại version hoặc loại đã chọn."
fi

# Xóa file .sh
rm -f wp_download.sh
