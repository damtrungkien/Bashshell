# Tăng thông số PHP
sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 512M/' php.ini
sudo sed -i 's/post_max_size = .*/post_max_size = 512M/' php.ini
sudo sed -i 's/memory_limit = .*/memory_limit = 1024M/' php.ini
sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' php.ini
sudo sed -i 's/max_input_time = .*/max_input_time = 300/' php.ini
sudo sed -i 's/max_file_uploads = .*/max_file_uploads = 512/' php.ini
sudo sed -i 's/max_input_vars = .*/max_input_vars = 1000/' php.ini