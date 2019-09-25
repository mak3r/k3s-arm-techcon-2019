# Order:
* ~~more batteries?~~
* ~~rpi3A+ devices (2)?~~
* ~~faster sd cards~~
* ~~router~~

# Software:
## Master service detects main outage and begins trasfer control
* use power-pod.yaml which used the mak3r/pd-inaction container
* do something useful when detected.


## ++ Create a service for the receivers
```
Transfer control process
- tar a file in another directory (/var/lib/rancher/k3s)
-- Can I put this in a config map
- choose a recipient (receiver)
-- use kubectl inside a pod to figure out which node
-- no, just deploy a pod (scout) k3s will figure out which one
- drain the receiver node
- actually if I deploy a pod with a replica set of 1. as long as the master is not also an agent, it will just pick a node
-- use kubectl inside a pod to figure out which node
- send the tar file to receiver node
-- Pull from config map or use ssh?
- receiver extract the tar file into the rancher directory
-- special pod
- tell all nodes to reconnect 
-- Is this necessary
-- no, it seems it is not necessary
```

## ~~ ++ Test the process with a 3 node cluster in which the 2 workers have processes running on them (eventually lighting leds)~~
## ++ is it possible to shorten the startup time by disable/enable a preinstalled /etc/systemd/system/k3s.service
* No. It doesn't seem to shorten startup time. But it does relive us of having to download the server every time.
* Suggestion is to preload agent and server systemd scripts on every node
## ++ create a scout workload that is a DaemonSet
* with scale min=1 max=1. 
* Whatever node the scout lands on, that's the node that will become master. 
* This allows us to "randomly" choose a node. 
* It also provides some additional capability to tweak the selection process if necessary in the future (e.g. devices that cannot be master)
## Setup nodes to be static ip reconfigured
This is necessary if 
* a) the network router and dns ever changes 
* b) to reset nodes to usable addresses easily if something goes wrong
* create a service that will detect a file in /boot at startup
* copy it to /etc/dhcpcd.conf
* enable it
## Update the username and password on the image

# Hardware:
add led capability?

# Build:
* More rpi3 A+ cases
* Base to stand up the cases

