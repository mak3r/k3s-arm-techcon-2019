#!/bin/sh

#check if the process is already activated
if test -f "/usr/local/share/k3s/m-enable-activated"
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

    # disable the k3s-agent
    systemctl disable k3s-agent
    # extract the archive to rancher k3s location
    tar -xvf /usr/local/share/k3s/k3s-archive.tar -C /var/lib/rancher/k3s/ --overwrite
    # overwrite the hostname in prep for reboot
    sed -i "s/$HOSTNAME/k3s-master/g" /host-etc/hosts && sudo /bin/sh -c "echo k3s-master > /host-etc/hostname"
    # set the master static ip address in prep for reboot
    cp /usr/local/share/k3s/dhcpcd.static.conf /boot/dhcpcd.conf
    # enable k3s in prep for reboot
    systemctl enable k3s

    # remove the activated file before reboot
    rm /usr/local/share/k3s/m-enable-activated

    # finalize the duration
    end=`date +%s`
    echo Script duration: $((end-start))

    # shutdown and bring the system back up
    reboot

fi