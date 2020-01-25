sudo date -s "$(curl -s --head http://google.com | grep ^Date: | sed 's/Date: //g')"
sudo timedatectl set-timezone Europe/Warsaw
