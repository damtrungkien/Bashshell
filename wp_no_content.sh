#!/bin/bash

# Kiểm tra curl
if ! command -v curl &>/dev/null; then
    echo "❌ Cần cài đặt 'curl' để chạy script này."
    exit 1
fi

# Gọi API WordPress
response=$(curl -s https://api.wordpress.org/core/version-check/1.7/)

# Trích xuất phiên bản mới nhất (dòng đầu tiên có "version")
latest_version=$(echo "$response" | grep '"version"' | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' | head -n 1)

# In kết quả
if [[ -n "$latest_version" ]]; then
    echo "✅ Phiên bản WordPress mới nhất là: $latest_version"
else
    echo "❌ Không thể lấy thông tin phiên bản."
fi
