#!/bin/bash

# Set up Telegram bot API and chat ID
BOT_API_KEY="YOUR_BOT_API_KEY"
CHAT_ID="YOUR_CHAT_ID"

# Check if MySQL service is running
if ! systemctl is-active --quiet mysql.service; then
  # If not running, send message to Telegram
  MESSAGE="🆘🆘🆘 - MySQL service is down!"
  curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d chat_id=$CHAT_ID -d text="$MESSAGE"
fi

# Check if Apache web server is running
if ! systemctl is-active --quiet apache2.service; then
  # If not running, send message to Telegram
  MESSAGE="🆘🆘🆘 - Apache web server is down!"
  curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d chat_id=$CHAT_ID -d text="$MESSAGE"
fi

# Check if PHP service is running
if ! systemctl is-active --quiet php.service; then
  # If not running, send message to Telegram
  MESSAGE="🆘🆘🆘 - PHP service is down!"
  curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d chat_id=$CHAT_ID -d text="$MESSAGE"
fi