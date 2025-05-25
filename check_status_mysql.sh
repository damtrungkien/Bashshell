#!/bin/bash

SERVICE='mysql' # Hoặc 'mariadb' nếu bạn đang sử dụng MariaDB

if ps ax | grep -v grep | grep $SERVICE > /dev/null
then
    echo "$SERVICE service running, everything is fine"
else
    echo "$SERVICE is not running"
    sudo service $SERVICE start
    echo "$SERVICE service has been started"
fi