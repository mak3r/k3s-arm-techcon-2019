#!/bin/bash

sudo cp /usr/local/share/k3s/dhcpcd.static.conf /boot/dhcpcd.conf
sudo /bin/bash -c 'sed -i "s/$HOSTNAME/k3s-master/g" /etc/hosts && echo k3s-master > /etc/hostname'
sudo systemctl enable k3s
sudo reboot
