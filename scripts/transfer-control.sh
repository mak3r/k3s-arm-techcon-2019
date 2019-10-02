#!/bin/bash

#check if the process is already activated
if test -f "/usr/local/share/k3s/tc-enable-activated"; then
    printf "." >> /usr/local/share/k3s/transfer-control.out
    exit 0;
fi

if test -f "/usr/local/share/k3s/tc-enable"; then
    # Log the script output
    exec 3>&1 4>&2
    trap 'exec 2>&4 1>&3' 0 1 2 3
    exec 1>/usr/local/share/k3s/transfer-control.out 2>&1

    #capture duration of this process
    start=`date +%s`
    
    # set a file so we don't try to repeat the process again and again if it's already running.
    touch /usr/local/share/k3s/tc-enable-activated

    # make sure we access the right cluster
    KUBECONFIG=/usr/local/share/k3s/kubeconfig.yaml

    #cleanup the enable file
    rm /usr/local/share/k3s/tc-enable

    cd /tmp
    # send out the scout for a new master
    kubectl apply -f /usr/local/share/k3s/scout.yaml --kubeconfig="$KUBECONFIG"
    # wait until scout is fully deployed
    STATUS="false"
    while [ "true" != "$STATUS" ]; do
        sleep 5
        STATUS=$(kubectl get pods -n k3s-arm-demo --selector=app=scout -o jsonpath='{.items[0].status.containerStatuses[0].ready}' --kubeconfig="$KUBECONFIG")
    done

    # drain master 
    # kubectl drain k3s-master --kubeconfig="$KUBECONFIG"
    # create an archive for the new master to use
    tar -cvf k3s-archive.tar -C /var/lib/rancher/k3s server/cred server/tls server/db server/manifests agent/kubeconfig.yaml agent/client-ca.pem
    
    # get the pod that scout is running as
    SCOUT_POD=$(kubectl get pods -n k3s-arm-demo --selector=app=scout -o jsonpath='{.items[0].metadata.name}' --kubeconfig="$KUBECONFIG")
    #copy the archive to scout
    kubectl cp k3s-archive.tar k3s-arm-demo/$SCOUT_POD:/usr/local/share/k3s/k3s-archive.tar --kubeconfig="$KUBECONFIG"
    # once copied write the enable flag
    kubectl exec --kubeconfig="$KUBECONFIG" -n k3s-arm-demo $SCOUT_POD -- /usr/bin/touch /usr/local/share/k3s/master-enable
    # find the node name of the worker using scout
    NODE_NAME=$(kubectl get pods -n k3s-arm-demo --selector=app=scout -o jsonpath='{.items[0].spec.nodeName}' --kubeconfig="$KUBECONFIG")
    # drain the worker that scout was on
    kubectl drain $NODE_NAME --kubeconfig="$KUBECONFIG"

    # rename the host to the former k3s worker name
    sed -i "s/$HOSTNAME/$NODE_NAME/g" /etc/hosts 
    echo "$NODE_NAME" > /etc/hostname

    # make sure this system does not become the k3s-master when it restarts.
    systemctl disable k3s

    # drop in a generic dhcpcd configuration
    cp /usr/local/share/k3s/dhcpcd.auto.conf /boot/dhcpcd.conf

    # finalize the duration
    end=`date +%s`
    echo Script duration: $((end-start))

    # remove the activated file before halt
    rm /usr/local/share/k3s/tc-enable-activated
    
    # and shutdown the original master
    /sbin/halt
fi
