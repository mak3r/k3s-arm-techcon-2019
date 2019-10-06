#!/bin/sh

#check if the process is already activated
if test -f "/usr/local/share/k3s/m-enable-activated"; then
    echo "master-enable in process" >> /usr/local/share/k3s/become_master.out
    exit 0;
fi

if test -f "/usr/local/share/k3s/master-enable"; then
    # Log the script output
    exec 3>&1 4>&2
    trap 'exec 2>&4 1>&3' 0 1 2 3
    exec 1>/usr/local/share/k3s/become_master.out 2>&1

    #capture duration of this process
    start=`date +%s`
    
    # set a file so we don't try to repeat the process again and again if it's already running.
    touch /usr/local/share/k3s/m-enable-activated

    # clean up
    rm /usr/local/share/k3s/master-enable

    # This process happens so fast, give the master some time to evict pods, etc.
    sleep 120

    # disable the k3s-agent
    systemctl disable k3s-agent
    # extract the archive to rancher k3s location
    tar -xvf /usr/local/share/k3s/k3s-archive.tar -C /var/lib/rancher/k3s/ --overwrite
    # overwrite the hostname in prep for reboot
    cp /usr/local/share/k3s/hosts /etc/hosts
    echo "k3s-master" > /etc/hostname
    # set the master static ip address in prep for reboot
    cp /usr/local/share/k3s/dhcpcd.static.conf /boot/dhcpcd.conf
    # enable k3s in prep for reboot
    systemctl enable k3s

    # finalize the duration
    end=`date +%s`
    echo Script duration: $((end-start))

    # remove the activated file 
    # and shutdown and bring the system back up
    rm /usr/local/share/k3s/m-enable-activated 
    /sbin/reboot

fi