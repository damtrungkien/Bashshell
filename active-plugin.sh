#!/bin/bash

# Các link plugin
plugins=(
    "https://downloads.wordpress.org/plugin/all-in-one-wp-migration.7.68.zip"
    "https://tainguyenwp.azdigi.com/WordPress-Plugins-Other/all-in-one-wp-migration-unlimited-extension.zip"
    "https://tainguyenwp.azdigi.com/WordPress-Plugins-Other/Elementskit.zip"
    "https://tainguyenwp.azdigi.com/WordPress-Plugins-Other/hummingbird-pro.zip"
    "https://tainguyenwp.azdigi.com/WordPress-Plugins-Other/ithemes-security-pro.zip"
    "https://tainguyenwp.azdigi.com/WordPress-Plugins-Other/otgs-installer-plugin.3.0.3.zip"
    "https://tainguyenwp.azdigi.com/WordPress-Plugins-Other/seedprod.zip"
    "https://tainguyenwp.azdigi.com/WordPress-Plugins-Other/seo-by-rank-math-pro.zip"
    "https://tainguyenwp.azdigi.com/WordPress-Plugins-Other/sitepress-multilingual-cms.4.5.5.zip"
    "https://tainguyenwp.azdigi.com/WordPress-Plugins-Other/smush-pro.zip"
    "https://tainguyenwp.azdigi.com/WordPress-Plugins-Other/wp-rocket_3.13.0.1.zip"
    "https://tainguyenwp.azdigi.com/WordPress-Plugins-Other/wpmu-dev-dashboard.zip"
    "https://tainguyenwp.azdigi.com/WordPress-Plugins-Other/wp-staging-pro.zip"
    "https://tainguyenwp.azdigi.com/WordPress-MyThemeShop/mythemeshop-connect.zip"
)

# Chạy wp-cli để cài đặt plugin
install_plugin() {
    plugin_name=$1
    wp plugin install ${plugin_name} --activate --allow-root
}

# Hàm so khớp mờ
fuzzy_match() {
    needle=$1
    haystack=("${@:2}")
    for item in "${haystack[@]}"; do
        if [[ "${item,,}" == *"${needle,,}"* ]]; then
            echo "${item}"
            return
        fi
    done
}

# Yêu cầu người dùng nhập tên plugin
read -p "Nhập tên plugin bạn muốn cài đặt: " plugin

# Tìm kiếm link plugin dựa trên tên nhập vào
matched_plugin=$(fuzzy_match "${plugin}" "${plugins[@]}")

if [[ -n "${matched_plugin}" ]]; then
    install_plugin "${matched_plugin}"
else
    echo "Không tìm thấy plugin phù hợp với tên '${plugin}'."
fi

rm -f ${pwdd}/active-plugin.sh