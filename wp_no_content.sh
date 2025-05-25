#!/bin/bash

# Kiểm tra curl
if ! command -v curl &>/dev/null; then
    echo "❌ Cần cài đặt 'curl' để chạy script này."
    exit 1
fi

echo "🔄 Đang lấy thông tin từ WordPress API..."
json=$(curl -s https://api.wordpress.org/core/version-check/1.7/)

# Trích xuất 5 phiên bản đầu tiên
versions=($(echo "$json" | grep -oP '"version"\s*:\s*"\K[0-9\.]+' | head -n 5))

echo "== 5 PHIÊN BẢN WORDPRESS MỚI NHẤT =="
for i in "${!versions[@]}"; do
    echo "$((i+1)). Version: ${versions[$i]}"
done

# Nhập lựa chọn
read -p $'\nNhập số phiên bản (1-5): ' ver_choice
read -p "Tải bản nào? (F = Full | N = No-content): " type_choice

# Xử lý lựa chọn
ver_index=$((ver_choice - 1))
selected_version="${versions[$ver_index]}"

if [[ "$type_choice" == "F" || "$type_choice" == "f" ]]; then
    file_url="https://wordpress.org/wordpress-${selected_version}.zip"
elif [[ "$type_choice" == "N" || "$type_choice" == "n" ]]; then
    file_url="https://wordpress.org/wordpress-${selected_version}-no-content.zip"
else
    echo "❌ Loại không hợp lệ. Chọn 'F' hoặc 'N'."
    exit 1
fi

# Tải file
file_name=$(basename "$file_url")
echo "⬇ Đang tải: $file_name ..."
curl -# -O "$file_url"

if [[ -f "$file_name" ]]; then
    echo "✅ Tải thành công: $file_name"
else
    echo "❌ Tải thất bại."
fi
