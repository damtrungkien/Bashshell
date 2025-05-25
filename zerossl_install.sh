#!/bin/bash
#Author: DOTRUNGQUAN.INFO
# Function to install SSL for main domain (option 1)
install_ssl_main_domain() {
    read -p "Nhập vào domain: " main_domain
    wget -O - https://get.acme.sh | sh -s email=ssl@azdigi.info
    bash /home/*/.acme.sh/acme.sh --issue --webroot ~/public_html -d $main_domain -d www.$main_domain --keylength 2048 --force
    bash /home/*/.acme.sh/acme.sh --deploy --deploy-hook cpanel_uapi --domain $main_domain --domain www.$main_domain
}

# Function to install SSL for addon domain (option 2)
install_ssl_addon_domain() {
    read -p "Nhập vào domain: " addon_domain
    wget -O - https://get.acme.sh | sh -s email=ssl@azdigi.info
    bash /home/*/.acme.sh/acme.sh --issue --webroot ~/$addon_domain -d $addon_domain -d www.$addon_domain --keylength 2048 --force
    bash /home/*/.acme.sh/acme.sh --deploy --deploy-hook cpanel_uapi --domain $addon_domain --domain www.$addon_domain
}

# Function to install SSL for addon domain (option 2)
install_ssl_sub_addon_domain() {
    read -p "Nhập vào domain: " sub_addon_domain
    wget -O - https://get.acme.sh | sh -s email=ssl@azdigi.info
    bash /home/*/.acme.sh/acme.sh --issue --webroot ~/$sub_addon_domain -d $sub_addon_domain --keylength 2048 --force
    bash /home/*/.acme.sh/acme.sh --deploy --deploy-hook cpanel_uapi --domain $sub_addon_domain 
}

# Main script
echo "Các tuỳ chọn:"
echo "1. Cài đặt Main Domain"
echo "2. Cài đặt addon Domain"
echo "3. Cài cho sub thêm dạng Addon"
read -p "Nhập vào (1 or 2 or 3): " option

case $option in
    1)
        install_ssl_main_domain
        ;;
    2)
        install_ssl_addon_domain
        ;;
    3)
        install_ssl_sub_addon_domain
        ;;
    *)
        echo "Nhập vào các tuỳ chọn 1,2 or 3"
        ;;
esac
