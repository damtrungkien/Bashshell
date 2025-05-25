#!/bin/bash

# Hàm lấy 10 phiên bản WordPress mới nhất
get_latest_versions() {
    response=$(curl -s "https://api.wordpress.org/core/version-check/1.7/")
    if [ $? -ne 0 ]; then
        echo "Lỗi khi lấy danh sách phiên bản từ API."
        exit 1
    fi

    # Trích xuất phiên bản từ JSON mà không dùng jq
    versions=$(echo "$response" | grep -o '"version":"[^"]*"' | awk -F'"' '{print $4}' | head -n 10)
    
    # Kiểm tra xem có phiên bản nào được trích xuất không
    if [ -z "$versions" ]; then
        echo "Không thể trích xuất danh sách phiên bản từ API response."
        exit 1
    fi

    echo "$versions"
}

# Hàm tải phiên bản WordPress
download_wordpress() {
    local version=$1
    url="https://wordpress.org/wordpress-$version.zip"
    echo "Đang tải WordPress phiên bản $version..."
    wget -q "$url" -O "wordpress-$version.zip"
    if [ $? -eq 0 ]; then
        echo "Đã tải về wordpress-$version.zip thành công!"
    else
        echo "Lỗi khi tải phiên bản $version."
    fi
}

# Main
main() {
    # Kiểm tra nếu curl và wget đã được cài đặt
    command -v curl >/dev/null2>&1 || { echo "Cần cài đặt curl. Vui lòng cài đặt bằng: sudo apt install curl (trên Ubuntu/Debian)"; exit 1; }
    command -v wget >/dev/null2>&1 || { echo "Cần cài đặt wget. Vui lòng cài đặt bằng: sudo apt install wget (trên Ubuntu/Debian)"; exit 1; }

    # Lấy danh sách phiên bản
    versions=($(get_latest_versions))
    if [ ${#versions[@]} -eq 0 ]; then
        echo "Không thể lấy danh sách phiên bản. Vui lòng thử lại sau."
        exit 1
    fi

    # In danh sách phiên bản
    echo "10 phiên bản WordPress mới nhất:"
    for i in "${!versions[@]}"; do
        echo "$((i+1)). ${versions[i]}"
    done

    # Yêu cầu người dùng chọn phiên bản
    while true; do
        read -p "Nhập số thứ tự phiên bản để tải (1-10, hoặc Enter để thoát): " choice
        if [ -z "$choice" ]; then
            echo "Đã thoát chương trình."
            exit 0
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#versions[@]} ]; then
            selected_version=${versions[$((choice-1))]}
            download_wordpress "$selected_version"
            break
        else
            echo "Vui lòng nhập số từ 1 đến ${#versions[@]}."
        fi
    done
}

main
