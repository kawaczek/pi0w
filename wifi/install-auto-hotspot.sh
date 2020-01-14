#!/bin/bash
# @author Laurent Blanes
#
# Credits goes to:
# https://www.raspberryconnect.com/projects/65-raspberrypi-hotspot-accesspoints/158-raspberry-pi-auto-wifi-hotspot-switch-direct-connection
#

C_END="\e[0m"
C_END_BG="\e[49m"
C_HIGHLIGHT="\e[38;5;34m"
C_HIGHLIGHT_BG="\e[102m"
C_CHANGE="\e[38;5;33m"
C_CHANGE_BG="\e[48;5;33m"
C_WARNING="\e[38;5;208m"
C_WARNING_BG="\e[48;5;208m"
FILE_EXISTS=0

function echoAction() { 
    echo -e "$C_HIGHLIGHT_BG $C_END_BG $C_HIGHLIGHT$1$C_END"
}

function echoChange() { 
    echo -e "$C_CHANGE_BG $C_END_BG $C_CHANGE$1$C_END"
}

function echoWarning() { 
    echo -e "$C_WARNING_BG $C_END_BG $C_WARNING$1$C_END"
}

echoAction "update the system"
sudo apt-get update
sudo apt-get upgrade -y

# INSTALL SOFTWARES
echoAction "install openssh-client to use SCP"
sudo apt-get install openssh-client -y

echoAction "install hostapd"
sudo apt-get install hostapd -y

echoAction "install dnsmasq"
sudo apt-get install dnsmasq -y

# Dnsmasq bug: in versions below 2.77 on Stretch and Jessie, 
# there is a bug that may cause the hotspot not to start for some users. 
# This can be resolved by removing the dns-root-data. 
# It may be benificial to do this before you start the rest of the installation 
# as it has been reported that doing it after installation for effected users does not work but you won't know 
# if it is an issue until after the installation is complete.

V=$(dpkg -s dnsmasq | grep Version | grep -oP '([0-9]\.[0-9]+)')
to_patch=$(expr $V \< 2.77)

if [ $to_patch ]; then
    echoWarning "# patch DNSMASQ bug"
    sudo apt-get purge dns-root-data -y
fi

# automatic startup needs to be disabled and by default hostapd is masked so needs to be unmasked
echoAction "disable automatic hotspot services"
sudo systemctl unmask hostapd
sudo systemctl disable hostapd
sudo systemctl disable dnsmasq

echoAction "configure hostapd"
# copy the following file to remote host
echoChange "copy hostapd conf"
sudo cp ./hostapd.conf /etc/hostapd/hostapd.conf

# change hostapd default file if not set yet
sudo grep -oP '#DAEMON_CONF=' /etc/default/hostapd
HOSTAPD_CHANGED=$?
# 0 = not changed
if [ $HOSTAPD_CHANGED == 0 ]; then
    echoChange "change hostapd"
    sudo sed -i "s/#DAEMON_CONF=\"\"/DAEMON_CONF=\"\/etc\/hostapd\/hostapd\.conf\"/g" /etc/default/hostapd
else
    echoAction "hostapd OK"
fi

# DNSMASQ
# echoAction "configure dnsmasq"
sudo grep -oP '#AutoHotspot' /etc/dnsmasq.conf > /dev/null
DNSMASQ_NOT_CHANGED=$?
if [ $DNSMASQ_NOT_CHANGED == 1 ]; then
    echoChange "change dnsmasq"
    # copy block at end of file
    cat <<EOF | sudo tee -a /etc/dnsmasq.conf > /dev/null
# 
# =================
#AutoHotspot Config
#stop DNSmasq from using resolv.conf
no-resolv
#Interface to use
interface=wlan0
bind-interfaces
dhcp-range=10.0.0.50,10.0.0.150,12h
EOF
else
    echoAction "dnsmasq OK"
fi

# INTERFACES
# echoAction "setting /etc/network/interfaces"
# check if /etc/network/interfaces exists
INTERFACE_FILE=/etc/network/interfaces
INTERFACE_FILE_BACKUP=/etc/network/interfaces-backup
sudo test -f $INTERFACE_FILE
INTERFACE_FILE_EXISTS=$?

if [ $INTERFACE_FILE_EXISTS == $FILE_EXISTS ]; then
    if [ ! -f "$INTERFACE_FILE_BACKUP" ]; then
        echoChange "backup $INTERFACE_FILE"
        sudo cp $INTERFACE_FILE $INTERFACE_FILE_BACKUP

        echoChange "create $INTERFACE_FILE"
        cat <<EOF | sudo tee $INTERFACE_FILE > /dev/null 
# interfaces(5) file used by ifup(8) and ifdown(8) 
# Please note that this file is written to be used with dhcpcd 
# For static IP, consult /etc/dhcpcd.conf and 'man dhcpcd.conf' 
# Include files from /etc/network/interfaces.d: 
# buster version
source-directory /etc/network/interfaces.d
# stretch version
# source /etc/network/interfaces.d
EOF
    else
        echoAction "interfaces OK"
    fi
fi

# DHCPCD
# echoAction "setting DHCPCD"
sudo touch /etc/dhcpcd.conf
sudo grep -oP 'nohook wpa_supplicant' /etc/dhcpcd.conf > /dev/null
DHCPCD_CHANGED=$?
if [ $DHCPCD_CHANGED == 1 ]; then
    echoChange "change dhcpcd.conf"
    cat <<EOF | sudo tee -a /etc/dhcpcd.conf >/dev/null
nohook wpa_supplicant
EOF
else
    echoAction "dhcpcd.conf OK"
fi

# AUTOHOTSPOT SERVICE
# echoAction "setting autohotspot service"
SERVICE_FILE=/etc/systemd/system/autohotspot.service
sudo test -f $SERVICE_FILE
SERVICE_FILE_EXISTS=$?

if [ $SERVICE_FILE_EXISTS == $FILE_EXISTS ]; then
    echoAction "$SERVICE_FILE OK"
else
    echoChange "create $SERVICE_FILE"
    cat <<EOF | sudo tee $SERVICE_FILE >/dev/null
[Unit]
Description=Automatically generates an internet Hotspot when a valid ssid is not in range
After=multi-user.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/autohotspot
[Install]
WantedBy=multi-user.target
EOF
fi

# COPY MAIN WIFI SWITCHING SCRIPT
echoChange "copy /usr/bin/autohotspot"
sudo cp ./autohotspot-script.sh /usr/bin/autohotspot
sudo chmod +x /usr/bin/autohotspot

# ENABLE autohotspot SERVICE
echoAction "start autohotspot service"
sudo systemctl enable autohotspot.service
