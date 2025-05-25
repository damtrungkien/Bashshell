#!/bin/bash

echo "======================================="
echo "  Download WordPress Full and No-Content"
echo "======================================="

# Lấy danh sách 5 phiên bản đầy đủ mới nhất từ API WordPress
versions=$(curl -s https://api.wordpress.org/core/version-check/1.7/ | grep -oP '(?<="version":")[^"]+' | head -n 5)

echo "📌 5 phiên bản WordPress đầy đủ mới nhất có sẵn:"
echo "$versions" | tr ' ' '\n'
echo "======================================="

# Nhập phiên bản từ người dùng (nếu không nhập, tải 5 bản đầy đủ và 5 bản no-content mới nhất)
while true; do
    read -p "Nhập phiên bản WordPress muốn tải (Enter để tải 5 bản đầy đủ và 5 bản no-content mới nhất): " version
    
    if [[ -z "$version" ]]; then
        echo "📌 Không nhập phiên bản. Mặc định tải về 5 phiên bản đầy đủ và 5 phiên bản no-content mới nhất!"
        for v in $versions; do
            # Tải phiên bản đầy đủ
            url_full="https://downloads.wordpress.org/release/wordpress-${v}.zip"
            file_name_full="wordpress-${v}.zip"
            echo "🔽 Đang tải về phiên bản đầy đủ: $url_full ..."
            wget -c "$url_full" -O "$file_name_full"
            if [[ $? -eq 0 ]]; then
                echo "✅ Tải về thành công: $file_name_full"
            else
                echo "❌ Lỗi! Không thể tải về: $file_name_full"
            fi

            # Tải phiên bản no-content
            url_nocontent="https://downloads.wordpress.org/release/wordpress-${v}-no-content.zip"
            file_name_nocontent="wordpress-${v}-no-content.zip"
            echo "🔽 Đang tải về phiên bản no-content: $url_nocontent ..."
            wget -c "$url_nocontent" -O "$file_name_nocontent"
            if [[ $? -eq 0 ]]; then
                echo "✅ Tải về thành công: $file_name_nocontent"
            else
                echo "❌ Lỗi! Không thể tải về: $file_name_nocontent"
            fi
        done
        break
    elif echo "$versions" | grep -q "^$version$"; then
        # Tải cả phiên bản đầy đủ và no-content cho phiên bản được chọn
        url_full="https://downloads.wordpress.org/release/wordpress-${version}.zip"
        file_name_full="wordpress-${version}.zip"
        echo "🔽 Đang tải về phiên bản đầy đủ: $url_full ..."
        wget -c "$url_full" -O "$file_name_full"
        if [[ $? -eq 0 ]]; then
            echo "✅ Tải về thành công: $file_name_full"
        else
            echo "❌ Lỗi! Không thể tải về: $file_name_full"
        fi

        url_nocontent="https://downloads.wordpress.org/release/wordpress-${version}-no-content.zip"
        file_name_nocontent="wordpress-${version}-no-content.zip"
        echo "🔽 Đang tải về phiên bản no-content: $url_nocontent ..."
        wget -c "$url_nocontent" -O "$file_name_nocontent"
        if [[ $? -eq 0 ]]; then
            echo "✅ Tải về thành công: $file_name_nocontent"
        else
            echo "❌ Lỗi! Không thể tải về: $file_name_nocontent"
        fi
        break
    else
        echo "❌ Phiên bản không hợp lệ! Vui lòng nhập lại một trong các phiên bản có sẵn."
    fi
done

# Xóa file .sh
rm -f wp_content.sh
