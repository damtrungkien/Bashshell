#!/bin/bash
# Damtrungkien.com

echo ">>>> Script Cài đặt WordPress <<<<"
read -p "- Nhap Name Databae : " wp_db
read -p "- Nhap User Database : " wp_user
read -p "- Nhap Pass Database : " wp_password
read -p "- Nhap ten website : " site_wp
read -p "- Nhap user admin : " user_wp
read -p "- Nhap pass admin : " pass_wp
read -p "- Nhap mail admin : " mail_wp

wp core download --allow-root
wp core config --dbname="$wp_db" --dbuser="$wp_user" --dbpass="$wp_password" --allow-root
wp core install --url="$site_wp" --title="Blog Title" --admin_user="$user_wp" --admin_password="$pass_wp" --admin_email="$mail_wp" --allow-root

rm -f wordpress_auto.sh

print("Cài đặt WordPress thành công!")