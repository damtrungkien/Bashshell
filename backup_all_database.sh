#!/bin/bash
#Auth: DAMTRUNGKIEN.COM
 
 
TIMESTAMP=$(date +"%d-%m-%Y")
BACKUP_DIR="/root/backup/$TIMESTAMP" ## Duong dan luu backup Database
MYSQL_USER="root"
MYSQL=/usr/bin/mysql
MYSQL_PASSWORD="passwd" ## Nhap Pass Root MYSQL
MYSQLDUMP=/usr/bin/mysqldump
SECONDS=0
 
mkdir -p "$BACKUP_DIR/mysql"

echo "Backup Database In Process";
databases=`$MYSQL --user=$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql)"`
 
for db in $databases; do
	$MYSQLDUMP --force --opt --user=$MYSQL_USER -p$MYSQL_PASSWORD $db | gzip > "$BACKUP_DIR/mysql/$db.gz"
done
echo "Backup Database Successful";