#!/bin/bash

# move the k3s-arm-demo-ns.yaml into the k3s manifests
cp workloads/k3s-arm-demo-ns.yaml /var/lib/rancher/k3s/server/manifests/k3s-arm-demo-ns.yaml
# move the power-pod.yaml into the k3s manifests 
cp workloads/power-pod.yaml /var/lib/rancher/k3s/server/manifests/power-pod.yaml
# move the scout.yaml to k3s share 
cp workloads/scout.yaml /usr/local/share/k3s/scout.yaml
# move the control scripts to /usr/bin
chmod 744 scripts/*.sh
cp scripts/become-master.sh /usr/bin/become-master.sh
cp scripts/transfer-control.sh /usr/bin/transfer-control.sh
# move dhcpcd configurations to k3s share
cp config/dhcpcd.static.conf /usr/local/share/k3s/.
cp config/dhcpcd.auto.conf /usr/local/share/k3s/.

