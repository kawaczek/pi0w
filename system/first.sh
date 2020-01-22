sudo date -s "$(curl -s --head http://google.com | grep ^Date: | sed 's/Date: //g')"
sudo apt update
sudo apt upgrade -y
sudo apt install git mc python-pip screen-y 
git clone --recursive https://github.com/kawaczek/pi0w
