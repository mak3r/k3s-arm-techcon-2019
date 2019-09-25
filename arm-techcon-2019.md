# Build notes
* Using rancher v0.5.0 as it is the latest version that can operate on very low amperage during startup of k3s. Later versions of k3s cause the board to go into a reboot cycle when the UPS is used. This is due to the low output amperage (~1000mA) of the PowerBoost 1000C. This is a known problem with the demo which will require a more robust UPS with similar functionality.

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

## Master (k3s-calf)
1. install systemd script to reduce power consumption `sudo systemctl enable reduce-power-consumption`
1. install k3s v0.3.0 `curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v0.3.0" INSTALL_K3S_EXEC=" --write-kubeconfig-mode=644 --node-ip=192.168.86.36" sh -`
1. install k3s v0.3.0 `curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v0.3.0" INSTALL_K3S_EXEC=" --write-kubeconfig-mode=644 --node-name=k3s-calf" sh -`
1. install k3s v0.9.0 `curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v0.9.0" INSTALL_K3S_EXEC=" --write-kubeconfig-mode=644 --node-ip=192.168.86.36" sh -`
1. get the node token `sudo cat /var/lib/rancher/k3s/server/node-token`

## Worker ()
1. install systemd script to reduce power consumption `sudo systemctl enable reduce-power-consumption`
1. install k3s v0.3.0 as agent
1. `curl -sfL https://get.k3s.io | K3S_URL="https://192.168.86.36:6443" INSTALL_K3S_VERSION="v0.3.0" K3S_TOKEN="K10647bc6fe82a602bd55a359d585ee7afdd27d2fc4de897093cd83bcaa2303013e::node:169b76e035617a11cb5de37f0bc6d09a" sh -`

## Transfer process
### On the original master
1. `kubectl drain <next_master>`
1. `kubectl drain <master_node>`
1. `sudo tar -cvf k3s-archive.tar -C /var/lib/rancher/k3s server/cred server/tls server/db`
1. `scp k3s-archive.tar pi@yellow-calf:~/.`
1. halt k3s master `sudo halt`
### On the new master
1. `sudo systemctl disable k3s-agent`
1. `sudo systemctl enable k3s`
1. `stop k3s on new node`
1. extract the archive `sudo tar -xvf k3s-archive.tar -C /var/lib/rancher/k3s/ --overwrite`
1. rename host `sudo sed -i "s/$HOSTNAME/<newname>/g" /etc/hosts && sudo /bin/sh -c "echo <newname> > /etc/hostname"`
1. change ip on node. Update /etc/dhcpcd.conf to use static ip address. 
    ```
    sudo /bin/bash -c 'echo "interface wlan0" >> /etc/dhcpcd.conf'
    sudo /bin/bash -c 'echo "static ip_address=$master_ip/24" >> /etc/dhcpcd.conf'
    sudo /bin/bash -c 'echo "static routers=192.168.86.1" >> /etc/dhcpcd.conf'
    sudo /bin/bash -c 'echo "static domain_name_servers=192.168.86.1" >> /etc/dhcpcd.conf'
    ```
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