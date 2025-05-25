#!/bin/bash
#Auth: Trung Kien

BACKUP_DIR="/home/admin/admin_backups/"  ## Đường dẫn chứa File Backup trên VPS
REMOTE=KIEN                              ## Tên Remote
SERVER_NAME=BACKUP_SERVER/KIEN           ## Đường dẫn lưu File Backup trên Google Drive
TIMESTAMP=$(date +"%d-%m-%Y")            ## Hiển thị ngày tháng năm



echo "Dang tien hanh Backup len Google Drive";
rclone copy $BACKUP_DIR $REMOTE:$SERVER_NAME/$TIMESTAMP >> /root/script/rclone.log 2>&1 #remote: remote config name created in previous step.

# Clean up
rm -rf $BACKUP_DIR  #Delete backup directory on VPS
rclone -q --min-age 8w delete "$REMOTE:$SERVER_NAME/$TIMESTAMP"
rclone -q --min-age 8w rmdirs "$REMOTE:$SERVER_NAME/$TIMESTAMP"
rclone cleanup "$REMOTE:$SERVER_NAME/$TIMESTAMP" #Cleanup Trash , Delete all files in trash directory
echo "Upload du lieu len Gooogle Drive hoan tat";
echo '';

duration=$SECONDS
echo "Total $size, $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."