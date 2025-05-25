#!/bin/bash

#Check if the version of Cyberpanel utilizes path or url
url=0
if grep -q "import url" /usr/local/CyberCP/CyberCP/urls.py; then
	url=1
fi

#Only make the changes if the version of Cyberpanel utilizes path and not url
if [ "$url" -eq 0 ]; then
	sed -i "s/url(r'^configservercsf/path('configservercsf/g" /usr/local/CyberCP/CyberCP/urls.py
	sed -i "s/url(r'^$'/path(''/g" /usr/local/CyberCP/configservercsf/urls.py
	sed -i "s|url(r'^iframe/\$'|path('iframe/'|g" /usr/local/CyberCP/configservercsf/urls.py
	sed -i "s/from django.conf.urls import url/from django.urls import path/g" /usr/local/CyberCP/configservercsf/urls.py
fi
sed -i "s/import signals/import configservercsf.signals/g" /usr/local/CyberCP/configservercsf/apps.py

sed -i -E "s/from.*, render/from plogical.httpProc import httpProc/g" /usr/local/CyberCP/configservercsf/views.py
sed -i -E "s#^(\s*)return render.*index\.html.*#\1proc = httpProc(request, 'configservercsf/index.html', None, 'admin')\n\1return proc.render()#g" /usr/local/CyberCP/configservercsf/views.py

find /usr/local/CyberCP/ -type d -name __pycache__ -exec rm -r {} \+; service lscpd restart && service lsws restart; killall lsphp