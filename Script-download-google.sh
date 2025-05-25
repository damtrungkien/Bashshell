#/bin/bash

echo ">>>> Script Download File Google_drive <<<<"
read -p "- Nhap ID Google_drive : " idgoogle
read -p "- Nhap ten File muon Download : " file
wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=${idgoogle}' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=${idgoogle}" -O ${file} && rm -rf /tmp/cookies.txt
rm -f Script-download-google.sh