#!/bin/bash

if test -f "/usr/local/share/k3s/tc-enable"; then
    # Log the script output
    exec 3>&1 4>&2
    trap 'exec 2>&4 1>&3' 0 1 2 3
    exec 1>/usr/local/share/k3s/trasfer-control.out 2>&1

    # make sure we access the right cluster
    KUBECONFIG=/var/lib/rancher/k3s/agent/kubeconfig.yaml

    #cleanup the enable file
    rm /usr/local/share/k3s/tc-enable

    #capture duration of this process
    start=`date +%s`

    cd /tmp
    # send out the scout for a new master
    kubectl apply -f /usr/local/share/k3s/scout.yaml --kubeconfig="$KUBECONFIG"
    
    ### ADD TEST HERE ###
    # CHECK IF SCOUT FOUND A SUFFICIENT HOME 
    # IF NOT, WE MAY NEED TO BAIL FROM THIS AND SEND AN ALERT VIA EMAIL INSTEAD
    #####################

    # drain master because it is also a worker
    kubectl drain k3s-master --kubeconfig="$KUBECONFIG"
    # create an archive for the new master to use
    sudo tar -cvf k3s-archive.tar -C /var/lib/rancher/k3s server/cred server/tls server/db server/manifests
    # get the pod that scout is running as
    SCOUT_POD=$(kubectl get pods -n k3s-arm-demo --selector=app=scout -o jsonpath='{.items[0].metadata.name}' --kubeconfig="$KUBECONFIG")
    #copy the archive to scout
    kubectl cp k3s-archive.tar k3s-arm-demo/$SCOUT_POD:/usr/local/share/k3s/k3s-archive.tar --kubeconfig="$KUBECONFIG"

    # make sure this system does not become the k3s-master when it restarts.
    systemctl disable k3s

    # drop in a generic dhcpcd configuration
    cp /usr/local/share/k3s/dhcpcd.auto.conf /boot/dhcpcd.conf

    # rename the host to the former k3s worker name
    NODE_NAME=kubectl get pods -n k3s-arm-demo --selector=app=scout -o jsonpath='{.items[0].spec.nodeName}' --kubeconfig="$KUBECONFIG"
    sed -i "s/$HOSTNAME/$NODE_NAME/g" /host-etc/hosts && sudo /bin/sh -c "echo $NODE_NAME > /host-etc/hostname"

    # finalize the duration
    end=`date +%s`
    echo Script duration: $((end-start))

    # Once the archive is received, the scout should begin initializing the server as the master shutdown the original master
    sudo halt
fi;
