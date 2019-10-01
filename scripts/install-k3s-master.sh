#!/bin/sh

curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v0.3.0" INSTALL_K3S_EXEC=" --write-kubeconfig-mode=644 --node-ip=192.168.8.11" sh -
