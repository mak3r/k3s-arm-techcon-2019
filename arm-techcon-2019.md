# Build notes
* Using rancher v0.3.0 as it is the latest version that can operate on very low amperage during startup of k3s. Later versions of k3s cause the board to go into a reboot cycle when the UPS is used. This is due to the low output amperage (~1000mA) of the PowerBoost 1000C. This is a known problem with the demo which will require a more robust UPS with similar functionality.

# Uninteruptable Power Supply (UPS) notes
The UPS is build from an Adafruit PowerBoost 1000C which has several useful functions.
* LiPo charger
* 5v output (unfortunately only 1A out with peak around 1.2A)
* Enable pin allows switched (on/off) operation
* Micro USB 5v in (to charge)
* USB pin is used to detect if the PowerBoost is plugged in or not
The USB pin (5v in) is connected to a voltage divider achieving 3.2v out. This is then attached to a GPIO pin on the raspberry pi which will detect 0v on the line if the USB input is disconnected. The PowerBoost will continue to operate on the LiPo battery. 

# BOM
## UPS
1. PowerBoost 1000C (adafruit)
1. SPDT switch (adafruit)
1. 2.1 amp micro USB power supply
1. 2000mAh 3.7v LiPo (adafruit and others)
1. header pins (various vendors)
1. connector wires (various vendors)


## Arm Hardware
* Raspberry Pi Model 3 A+ (adafruit and other vendors)
* 8GB micro SD - Class 10 or better U3 is best right now (various vendors)
* Raspbian stretch
* k3s v??

---------- 
# Device Prep
## is there an issue with later versions of k3s?
CPU load issue with k3s > v0.6.0?
https://github.com/rancher/k3s/issues/294

## Secure TLS in wpasupplicant
Add the following lines to wpa_supplicant.conf
```
tls_disable_tlsv1_0=1
tls_disable_tlsv1_1=1
openssl_ciphers=DEFAULT@SECLEVEL=2
```

## Set the hostname for each device
Add a file to the boot directory before startup `/boot/hostname`. This file should include the device hostname to use.

## Install a service to easily update the static ip address of each node at boot
This service file allows us to drop place a configuration at `/boot/dhcpcd.conf` which will get copied into `/etc/dhcpcd.conf` before the next reboot.

`sudo systemctl enable dhcpcd-init`
`/etc/systemd/system/dhcpcd-init.service`:
```
[Unit]
Description=Update the dhcpcd.conf when the system starts up
ConditionPathExists=/boot/dhcpcd.conf
Before=dhcpcd.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/mv /boot/dhcpcd.conf /etc/dhcpcd.conf
ExecStartPost=/bin/chmod 664 /etc/dhcpcd.conf
ExecStartPost=/bin/chown root:netdev /etc/dhcpcd.conf

[Install]
WantedBy=multi-user.target
```

## Reduce power consumption on the Pi
Thanks to https://learn.pi-supply.com/make/how-to-save-power-on-your-raspberry-pi/. View this site for info on how to turn these things back on.
### Turn off the USB bus 
* `echo 'usb1' |sudo tee /sys/bus/usb/drivers/usb/unbind`
* Validate with `sudo ls -la /sys/bus/usb/drivers/usb`. There should no longer be a link from usb1 -> device
#### EXAMPLE ON
``` 
$ sudo ls -la /sys/bus/usb/drivers/usb
total 0
drwxr-xr-x  2 root root    0 Sep 22 13:40 .
drwxr-xr-x 10 root root    0 Sep 22 03:00 ..
--w-------  1 root root 4096 Sep 22 13:40 bind
--w-------  1 root root 4096 Sep 22 13:40 uevent
--w-------  1 root root 4096 Sep 22 13:37 unbind
lrwxrwxrwx  1 root root    0 Sep 22 13:40 usb1 -> ../../../../devices/platform/soc/3f980000.usb/usb1
```
#### EXAMPLE OFF
```
$ sudo ls -la /sys/bus/usb/drivers/usb
total 0
drwxr-xr-x  2 root root    0 Sep 22 13:40 .
drwxr-xr-x 10 root root    0 Sep 22 03:00 ..
--w-------  1 root root 4096 Sep 22 13:40 bind
--w-------  1 root root 4096 Sep 22 13:40 uevent
--w-------  1 root root 4096 Sep 22 13:37 unbind
```

### Turn off HDMI output
* `sudo /opt/vc/bin/tvservice -o`
* Validate with `tvservice -s`
#### EXAMPLE OFF
```
$ tvservice -s
state 0x120001 [TV is off]
```

### create a service to reduce power consumption
`/etc/systemd/system/reduce-power-consumption.service`:
```
[Unit]
Description=Reduce power consuption of the device by disabling USB and HDMI 
After=multi-user.target

[Service]
Type=simple
ExecStartPre=-/opt/vc/bin/tvservice -o
ExecStartPre=-/bin/sh -c 'echo "usb1" | tee /sys/bus/usb/drivers/usb/unbind'
ExecStart=-/bin/echo "reducing power consumption"

[Install]
WantedBy=multi-user.target
```

### Underclock the device
This is reported to have little effect on current draw and may not be worth it since it will slow the demo down.
This definitely requires the devices to bring up k3s much slower.
Add the following lines to `/boot/config.txt`
```
arm_freq_min=250
core_freq_min=100
sdram_freq_min=150
over_voltage_min=0
```

------------- 
# System setup
## Install master role and worker on every node
1. install k3s v0.3.0 `curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v0.3.0" INSTALL_K3S_EXEC=" --write-kubeconfig-mode=644 --node-ip=192.168.86.36" sh -`
1. disable k3s `sudo systemctl disable k3s`

## Master (k3s-master)
1. Configure with hostname `k3s-master` and static ip `192.168.8.11`
1. install systemd script to reduce power consumption `sudo systemctl enable reduce-power-consumption`
1. install k3s v0.3.0 `curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v0.3.0" INSTALL_K3S_EXEC=" --write-kubeconfig-mode=644 --node-ip=192.168.8.11 --tls-san=192.168.8.11 --write-kubeconfig=/usr/local/share/k3s/kubeconfig.yaml" sh -`
1. disable the master `sudo systemctl disable k3s`
1. install the agent script `curl -sfL https://get.k3s.io | K3S_URL="https://192.168.8.11:6443" INSTALL_K3S_VERSION="v0.3.0" K3S_TOKEN_FILE="/var/lib/rancher/k3s/server/node-token" sh -`
1. disable the agent `sudo systemctl disable k3s-agent`
1. start the master `sudo systemctl enable k3s`


## Workers (k3s-workerNNN)
1. duplicate master image
    * disable k3s
    * disable k3s-agent
    * clean extraneous files from `/usr/local/share/k3s`
1. Configure with hostname `k3s-workerNNN` and static ip `192.168.8.NNN` where NN is a value 12-99 and unique to the cluster.
1. reset to use auto configuration of dhcpcd
1. `sudo systemctl disable k3s`
1. enable the agent `sudo systemctl enable k3s-agent`

## k3s cluster configuration
* This should eventually be automated as failure to do this will cause the demo to fail!
* All nodes should be able to run as all roles so once the setup is configured, an image should be created and replicated to all nodes in the cluster.
1. link from the k3s.yaml to the installed location due to this issue (https://github.com/rancher/k3s/issues/378) which is fixed in 0.6.0 
```
sudo mkdir -p /etc/rancher/k3s
sudo ln -s /var/lib/rancher/k3s/agent/kubeconfig.yaml /etc/rancher/k3s/k3s.yaml
```
1. label the master node with `kubectl label node k3s-master nodetype=master`
1. label the worker nodes with `kubectl label node k3s-workerNN nodetype=worker`
```
#!/bin/bash

# move the k3s-arm-demo-ns.yaml into the k3s manifests
cp workloads/k3s-arm-demo-ns.yaml /var/lib/rancher/k3s/server/manifests/k3s-arm-demo-ns.yaml
# move the power-pod.yaml into the k3s manifests 
cp workloads/power-pod.yaml /var/lib/rancher/k3s/server/manifests/power-pod.yaml
# move the scout.yaml to k3s share 
cp workloads/scout.yaml /usr/local/share/k3s/scout.yaml
# move the control scripts to /usr/bin
cp scripts/become-master.sh /usr/bin/become-master.sh
cp scripts/transfer-control.sh /usr/bin/transfer-control.sh
```


## Transfer process
* master needs affinity for `kubectl-pod` 
* workers need anti-affinity or taints for `scout` and for LED workloads
### On the original master
1. deploy the scout `kubectl apply -f scout.yaml`
1. ~~`kubectl drain <master_node>`~~
1. `sudo tar -cvf k3s-archive.tar -C /var/lib/rancher/k3s server/cred server/tls server/db server/manifests`
1. ~~`scp k3s-archive.tar pi@yellow-calf:~/.`~~
1. `kubectl cp k3s-archive.tar scout`
1. Tell new master to initialize `kubectl exec power_up_job power_up.sh`
1. halt k3s original master `sudo halt`
### On the new master
1. `sudo systemctl disable k3s-agent`
1. extract the archive `sudo tar -xvf k3s-archive.tar -C /var/lib/rancher/k3s/ --overwrite`
1. rename host `sudo sed -i "s/$HOSTNAME/<newname>/g" /etc/hosts && sudo /bin/sh -c "echo <newname> > /etc/hostname"`
1. change ip on node. Update /etc/dhcpcd.conf to use static ip address. 
    ```
    sudo /bin/bash -c 'echo "interface wlan0" >> /etc/dhcpcd.conf'
    sudo /bin/bash -c 'echo "static ip_address=$master_ip/24" >> /etc/dhcpcd.conf'
    sudo /bin/bash -c 'echo "static routers=192.168.86.1" >> /etc/dhcpcd.conf'
    sudo /bin/bash -c 'echo "static domain_name_servers=192.168.86.1" >> /etc/dhcpcd.conf'
    ```
1. `sudo systemctl enable k3s`
1. reboot
1. Q&A and slides
1. Remove the old node `kubectl delete <node_name>`
1. Uncordon master

### On the workstation or hand controller - to show what's going on
1. ??? scale down one of the led jobs ??? `kubectl scale --replicas=2 -f blue.yaml`
1. ??? scale up one of the led jobs ???

--------- 
# Debug things
## Agent
* `journalctl -u k3s-agent`

## Any Node
* `systemd-analyze blame`

## Master
* `kubectl exec -it -n k3s-arm-demo power-pod-9f48c7b89-ghzgw /bin/bash`
