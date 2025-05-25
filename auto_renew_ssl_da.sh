#!/bin/bash
#Auth: DAMTRUNGKIEN.COM

# Ngưỡng cảnh báo (15 ngày)
THRESHOLD=15

# Duyệt qua tất cả các domain theo cấu trúc /home/*/domains/*
for domain_path in /home/*/domains/*; do
    domain=$(basename "$domain_path")
    user=$(basename "$(dirname "$(dirname "$domain_path")")")

    cert_file="/usr/local/directadmin/data/users/${user}/domains/${domain}.cert.combined"

    if [ -f "$cert_file" ]; then
        # Trích xuất ngày hết hạn từ file cert.combined
        expire_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
        expire_timestamp=$(date -d "$expire_date" +%s)
        now_timestamp=$(date +%s)
        days_left=$(( (expire_timestamp - now_timestamp) / 86400 ))

        echo "Domain: $domain - SSL còn $days_left ngày"

        # Nếu còn dưới ngưỡng, tiến hành gia hạn
        if [ "$days_left" -le "$THRESHOLD" ]; then
            echo ">> Gia hạn SSL cho $domain"
            /usr/local/directadmin/scripts/letsencrypt.sh request "$domain"
        fi
    else
        echo "Domain: $domain - Không tìm thấy chứng chỉ SSL"
    fi
done