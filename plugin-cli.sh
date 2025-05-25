#!/bin/bash
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
pwdd=`pwd`
# Mảng chứa danh sách các plugin
# "") install_and_activate_plugin "";;
plugins=('Litespeed cache'
"Wordfence"
"Really simple SSL"
"Anti-Malware Security"
"Redis cache"
"Better search replace"
"Query monitor"
"Fastest cache"
"iThemes Security Pro"
"WPMU Dev Dashboard"
"SEO by Rank Math Pro"
"Elementskit"
"Sitepress-multilingual"
"Seedprod"
"wp-staging"
"Thoát")

#################################################################################

# Hàm cài đặt và kích hoạt plugin
install_and_activate_plugin() {
    plugin_url=$1
    wp plugin install "$plugin_url" --activate --allow-root
}
# Hàm cài đặt và kích hoạt Theme
install_and_activate_theme() {
    plugin_url=$1
    wp theme install "$plugin_url" --activate --allow-root
}
# Hàm hiển thị danh sách plugin đã cài đặt
display_installed_plugins() {
    wp plugin list --allow-root
}

# Hàm tắt alll plugin
disable_all_plugin() {
wp plugin deactivate --all --allow-root
}
# Hàm Enable all plugin alll plugin
enable_all_plugin() {
wp plugin activate --all --allow-root
}
# Hàm xoá plugin
delete_plugin() {
    # Hiển thị danh sách plugin
    wp plugin list --allow-root | awk 'NR > 2 {print $1}'
    # Nhập tên plugin cần xoá
    read -p "Nhập tên plugin cần xoá: " plugin_name
    # Kiểm tra xem plugin có tồn tại không
    if wp plugin list --allow-root | grep -q "$plugin_name"; then
        wp plugin deactivate "$plugin_name" --allow-root
        wp plugin delete "$plugin_name" --allow-root
        echo "Đã xoá plugin $plugin_name thành công."
    else
        echo "Không tìm thấy plugin $plugin_name."
    fi
}
# Hàm update plugin
update_plugin() {
    # Hiển thị danh sách plugin
    wp plugin list --allow-root | awk 'NR > 2 {print $1}'
    # Nhập tên plugin cần update_plugin
    read -p "Nhập tên plugin cần update: " plugin_update
    # Kiểm tra xem plugin có tồn tại không
    if wp plugin list --allow-root | grep -q "$plugin_update"; then
        wp plugin update "$plugin_update" --allow-root
        echo "Đã update plugin $plugin_update thành công."
    else
        echo "Không tìm thấy plugin $plugin_update."
    fi
}

#Hàm update all plugin
update_all_plugin() {
wp plugin update --all --allow-root
}

#################################################################################

#Hàm Hiện Show Theme.
show_theme_list() {
wp theme list --allow-root
}

#################################################################################

#Hàm list User.
show_user_list() {
wp user list --allow-root
}


#Hàm tạo User.
creat_user() {
    # Nhập tên User cần tạo
    read -p "Nhập tên user cần tạo: " user1_name
        # Kiểm tra xem User có tồn tại không
    if wp user list --allow-root | grep -q "$user1_name"; then
        wp user create "$user1_name" admin@kythuat.com --role=administrator --allow-root
        echo "Đã tạo user $user1_name thành công."
        wp user list --allow-root
    else
        echo "Không tìm thấy User $user1_name."
    fi
}

#Hàm change pass User.
change_pass_user() {
    # Hiển thị danh sách user
    wp user list --allow-root
    # Nhập tên user cần change
    read -p "Nhập tên user: " user2_name
    read -p "Nhập pass mới: " pass2_name
    # Kiểm tra xem user có tồn tại không
    if wp user list --allow-root | grep -q "$user2_name"; then
        wp user update "$user2_name" --user_pass="$pass2_name" --allow-root
        echo "Đã đổi pass user $user2_name thành công."
    else
        echo "Không tìm thấy user $user2_name."
    fi
}

#Hàm xoá User.
delete_user() {
    # Hiển thị danh sách user
    wp user list --allow-root
    # Nhập tên user cần xoá
    read -p "Nhập tên user muốn xoá: " user3_name
    read -p "Nhập ID user: " id3_name
    # Kiểm tra xem user có tồn tại không   
    if wp user list --allow-root | grep -q "$user3_name"; then
        wp user delete "$user3_name" --reassign="$id3_name" --allow-root
        echo "Đã xoá user $user3_name thành công."
        wp user list --allow-root
    else
        echo "Không tìm thấy user $user3_name."
    fi
}

#Hàm update quyền User
update_user() {
    # Hiển thị danh sách User
    wp user list --allow-root
    # Nhập tên User cần update
    read -p "Nhập tên user cần update quyền: " user4_name
    # Kiểm tra xem User có tồn tại không
    if wp user list --allow-root | grep -q "$user4_name"; then
        wp user update "$user4_name" --role=administrator --allow-root
        echo "Đã update quyền User $user4_name thành công."
        wp user list --allow-root
    else
        echo "Không tìm thấy User $user4_name."
    fi
}

#################################################################################

while true; do
    # Hiển thị menu chọn lựa
    PS3="Chọn plugin để cài đặt (hoặc 0 để thoát): "
    select plugin_name in "${plugins[@]}"; do
        case $plugin_name in
            "Litespeed cache") install_and_activate_plugin litespeed-cache ;;
            "Wordfence") install_and_activate_plugin wordfence ;;
            "Really simple SSL") install_and_activate_plugin really-simple-ssl ;;
            "Anti-Malware Security") install_and_activate_plugin gotmls ;;
            "Redis cache") install_and_activate_plugin redis-cache ;;
            "Better search replace") install_and_activate_plugin better-search-replace ;;
            "Query monitor") install_and_activate_plugin query-monitor ;;
            "Fastest cache") install_and_activate_plugin wp-fastest-cache ;;
            "iThemes Security Pro") install_and_activate_plugin "https://tool.damtrungkien.com/plugin/ithemes-security-pro-7.3.3.zip" ;;
            "WPMU Dev Dashboard") install_and_activate_plugin "https://tool.damtrungkien.com/plugin/wpmu-dev-dashboard-4.11.18.zip" ;;
            "SEO by Rank Math Pro") install_and_activate_plugin "https://tool.damtrungkien.com/plugin/seo-by-rank-math-pro.zip" ;;
            "Elementskit") install_and_activate_plugin "https://tool.damtrungkien.com/plugin/elementskit-3.6.1.zip" ;;        
            "Sitepress-multilingual") install_and_activate_plugin "https://tool.damtrungkien.com/plugin/sitepress-multilingual-cms.4.6.10.zip";;
            "Seedprod") install_and_activate_plugin "https://tool.damtrungkien.com/plugin/seedprod-coming-soon-pro-5-6.15.12.zip";;
            "wp-staging") install_and_activate_plugin "https://tool.damtrungkien.com/plugin/wp-staging-pro.zip";;
            "Thoát") echo "Thoát chương trình.";
            rm -f ${pwdd}/plugin-cli.sh;
            exit ;;
            #"Thoat") echo "Thoát chương trình."; exit ;;
            *) echo "Lựa chọn không hợp lệ. Hãy chọn lại." ;;
        esac
        break
    done
done
