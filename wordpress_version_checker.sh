#!/bin/bash

# Kiểm tra xem curl có được cài đặt hay không
if ! command -v curl &> /dev/null; then
    echo "Lỗi: curl chưa được cài đặt. Vui lòng cài đặt curl để tiếp tục."
    exit 1
fi

# Lấy dữ liệu từ API WordPress
echo "Đang lấy thông tin phiên bản từ WordPress API..."
response=$(curl -s https://api.wordpress.org/core/version-check/1.7/)

# Kiểm tra xem có lấy được dữ liệu hay không
if [ -z "$response" ]; then
    echo "Lỗi: Không thể lấy dữ liệu từ API."
    exit 1
fi

# Lấy 5 phiên bản đầy đủ và 5 phiên bản no-content
full_versions=($(echo "$response" | grep -o '"version":"[^"]*"' | awk -F'"' '{print $4}' | grep -v "^$" | sort -V | uniq | head -n 5))
no_content_versions=($(echo "$response" | grep -o '"version":"[^"]*"' | awk -F'"' '{print $4}' | grep -v "^$" | sort -V | uniq | head -n 5))

# Kiểm tra xem có dữ liệu phiên bản hay không
if [ ${#full_versions[@]} -eq 0 ] && [ ${#no_content_versions[@]} -eq 0 ]; then
    echo "Lỗi: Không tìm thấy phiên bản nào từ API."
    exit 1
fi

# In danh sách các phiên bản đầy đủ
echo -e "\nCác phiên bản đầy đủ (Full Package):"
for i in "${!full_versions[@]}"; do
    version=${full_versions[$i]}
    package_url=$(echo "$response" | grep -o "\"version\":\"$version\".*\"package\":\"[^\"]*\"" | awk -F'"package":"' '{print $2}' | awk -F'"' '{print $1}' | head -n 1)
    if [ -n "$package_url" ]; then
        echo "$((i+1)). Phiên bản $version - URL: $package_url"
    else
        echo "$((i+1)). Phiên bản $version - URL: Không có"
    fi
done

# In danh sách các phiên bản no-content
echo -e "\nCác phiên bản no-content:"
for i in "${!no_content_versions[@]}"; do
    version=${no_content_versions[$i]}
    package_url=$(echo "$response" | grep -o "\"version\":\"$version\".*\"package_no_content\":\"[^\"]*\"" | awk -F'"package_no_content":"' '{print $2}' | awk -F'"' '{print $1}' | head -n 1)
    if [ -n "$package_url" ]; then
        echo "$((i+1)). Phiên bản $version - URL: $package_url"
    else
        echo "$((i+1)). Phiên bản $version - URL: Không có"
    fi
done

# Yêu cầu người dùng nhập phiên bản và loại gói
echo -e "\nNhập phiên bản bạn muốn tải (ví dụ: 6.6.2):"
read version_input
echo "Chọn loại gói (1: Full Package, 2: No-content Package):"
read package_type

# Kiểm tra đầu vào của người dùng
if [ -z "$version_input" ] || [ -z "$package_type" ]; then
    echo "Lỗi: Vui lòng nhập đầy đủ phiên bản và loại gói."
    exit 1
fi

# Tìm URL tải về dựa trên phiên bản và loại gói
if [ "$package_type" == "1" ]; then
    package_url=$(echo "$response" | grep -o "\"version\":\"$version_input\".*\"package\":\"[^\"]*\"" | awk -F'"package":"' '{print $2}' | awk -F'"' '{print $1}' | head -n 1)
elif [ "$package_type" == "2" ]; then
    package_url=$(echo "$response" | grep -o "\"version\":\"$version_input\".*\"package_no_content\":\"[^\"]*\"" | awk -F'"package_no_content":"' '{print $2}' | awk -F'"' '{print $1}' | head -n 1)
else
    echo "Lỗi: Loại gói không hợp lệ. Vui lòng chọn 1 hoặc 2."
    exit 1
fi

# Kiểm tra xem URL có tồn tại không
if [ -z "$package_url" ]; then
    echo "Lỗi: Không tìm thấy gói cho phiên bản $version_input."
    exit 1
fi

# Tải file về
echo "Đang tải gói từ $package_url..."
curl -O "$package_url"

if [ $? -eq 0 ]; then
    echo "Tải về thành công!"
else
    echo "Lỗi: Tải về thất bại."
    exit 1
fi

# Tự xóa script sau khi hoàn thành
script_path=$(realpath "$0")
echo "Xóa script $script_path..."
rm -f "$script_path"

if [ $? -eq 0 ]; then
    echo "Script đã được xóa."
else
    echo "Lỗi: Không thể xóa script."
    exit 1
fi
