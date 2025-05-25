#!/bin/bash

# URL chứa danh sách các phiên bản WordPress
URL="https://wordpress.org/download/releases/"

# Hàm kiểm tra và lấy 5 phiên bản mới nhất
get_latest_wordpress_versions() {
    # Tải nội dung trang web và xử lý lỗi
    content=$(curl -s "$URL")
    if [ $? -ne 0 ]; then
        echo "Lỗi: Không thể tải trang $URL"
        exit 1
    fi

    # Trích xuất các phiên bản từ bảng HTML
    # Giả sử các phiên bản nằm trong thẻ <td> đầu tiên của mỗi hàng
    versions=$(echo "$content" | grep -oP '<td>\d+\.\d+\.\d+(?:-\w+)?</td>' | head -n 5 | sed 's/<td>\(.*\)<\/td>/\1/')

    if [ -z "$versions" ]; then
        echo "Lỗi: Không tìm thấy thông tin phiên bản trên trang."
        exit 1
    fi

    echo "5 phiên bản WordPress mới nhất:"
    echo "$versions" | while read -r version; do
        echo "- $version"
    done
}

# Gọi hàm
get_latest_wordpress_versions
