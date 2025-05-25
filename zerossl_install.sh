#!/bin/bash
#DAMTRUNGKIEN
echo "Install ZeroSSL_cPanel ( Nameserver  ns3-ns4 | va Domain da tro A, WWW, MAIL ve IP goi Host"

homeuser=$(echo $PWD)

echo -n "Moi nhap email: "
read emailkhach

echo -n "Nhap Domain chinh cua Host: "
read main_domain

echo -n "Nhap Domain chinh de cai SSL (Neu khong cai ssl cho Domain chinh thi nhap 'KHONG'): "
read main_domain1

wget -O - https://get.acme.sh | sh -s email=$emailkhach

if [ $main_domain1 != $main_domain ]
then
  echo "Khong cai dat ssl cho $main_domain"
else
  $homeuser/.acme.sh/acme.sh --issue --webroot $homeuser/public_html -d $main_domain -d www.$main_domain --force
  sleep 3
  $homeuser/.acme.sh/acme.sh --deploy --deploy-hook cpanel_uapi --domain $main_domain --domain www.$main_domain
  sleep 3
fi

read -p "Nhap Domain addon de cai dat ZeroSSL: " tenmien_ssl

for listaddon in $tenmien_ssl
do
  echo $listaddon >> $homeuser/list_addon.txt

done

for zerossl in `\cat $homeuser/list_addon.txt` ;
do
  $homeuser/.acme.sh/acme.sh --issue --webroot $homeuser/$zerossl -d $zerossl -d www.$zerossl  --force
  $homeuser/.acme.sh/acme.sh --deploy --deploy-hook cpanel_uapi --domain $zerossl --domain www.$zerossl 
done

rm -rf $homeuser/list_addon.txt
rm -rf $homeuser/zerossl_install.sh