#!/bin/sh

systemctl disable k3s-agent
tar -xvf k3s-archive.tar -C /var/lib/rancher/k3s/ --overwrite
sed -i "s/$HOSTNAME/k3s-master/g" /host-etc/hosts && sudo /bin/sh -c "echo k3s-master > /host-etc/hostname"
cp /usr/local/share/k3s/dhcpcd.static.conf /boot/dhcpcd.conf
systemctl enable k3s
reboot

# Do a default job when the sytem comes back up to moo