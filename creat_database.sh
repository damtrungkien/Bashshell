#!/bin/bash

echo ">>>> Script Cài đặt WordPress <<<<"
read -p "- Nhap Name Databae : " wp_db
read -p "- Nhap User Database : " wp_user
read -p "- Nhap Pass Database : " wp_password
read -p "- Nhap ten website : " site_wp
read -p "- Nhap user admin : " user_wp
read -p "- Nhap pass admin : " pass_wp
read -p "- Nhap mail admin : " mail_wp

# Tạo cơ sở dữ liệu và người dùng
mysql -e "CREATE DATABASE $wp_db;"
mysql -e "CREATE USER '$wp_user'@'localhost' IDENTIFIED BY '$wp_password';"
mysql -e "GRANT ALL PRIVILEGES ON $wp_db.* TO '$wp_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"
