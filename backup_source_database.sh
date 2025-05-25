#!/bin/bash
#Auth: DAMTRUNGKIEN.COM
 
TIMESTAMP=$(date +"%d-%m-%Y")
BACKUP_DIR="/root/backup/$TIMESTAMP" ## Duong dan lưu Backup
MYSQL_USER="root"                    ## Nhap User Root MYSQL
MYSQL=/usr/bin/mysql
MYSQL_PASSWORD="passwd"              ## Nhap Pass Root MYSQL
MYSQLDUMP=/usr/bin/mysqldump
SECONDS=0
 
########## Backup Mysql ##########
mkdir -p "$BACKUP_DIR/Mysql"

echo "Backup Database In Process";
databases=`$MYSQL --user=$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql)"`
 
for db in $databases; do
	$MYSQLDUMP --force --opt --user=$MYSQL_USER -p$MYSQL_PASSWORD $db | gzip > "$BACKUP_DIR/Mysql/$db.gz"
done
echo "Backup Database Successful";
echo '';

########## Backup Source ##########
mkdir -p "$BACKUP_DIR/Source"

echo "Backup Source In Process";
# Loop through /home directory
for D in /home/*; do
	if [ -d "${D}" ]; then #If a directory
		domain=${D##*/} # Domain name
		echo "- "$domain;
		zip -r $BACKUP_DIR/Source/$domain.zip /home/$domain/public_html/ -q -x /home/$domain/public_html/wp-content/litespeed/**\* *.sql *.zip *.tar.gz *.wpress
	fi
done
echo "Backup Source Successful";
echo '';