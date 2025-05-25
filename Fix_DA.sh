#!/bin/bash
#Auth: Trung Kien

mv /usr/local/directadmin/custombuild /usr/local/directadmin/custombuild.bak-goc
cd /usr/local/directadmin/
git clone https://github.com/skinsnguyen/custombuild.git
mv /usr/local/directadmin/custombuild/options.conf /usr/local/directadmin/custombuild/options.conf.bak-github
cd /usr/local/directadmin/custombuild/
cp ../custombuild.bak-goc/options.conf .
/usr/bin/perl -pi -e 's/^downloadserver=.*/downloadserver=files.directadmin.com/' options.conf


