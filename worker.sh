#!/bin/bash

# utilities functions (logging) 
log() {
 echo "$(date "+%F %T.%2N")|$(hostname)|${*}"
}

debug() {
 log "DEBUG|${*}"
}

info() {
 log "INFO|${*}"
}

warn() {
 log "WARN|${*}"
}

error() {
 log "ERROR|${*}"
}

#default peering subnet for the cluster
PEER_SUBNET="192.168.66.0"

wrong_arg(){
 error "Invalid parameter for $1"
 exit "1"
}

while [ $# -gt 0 ]; do
case "$1" in
  -s|--subnet)
    PEER_SUBNET="$2"
    shift 2
    ;;
  -s|--node_ip)
    WORKER_ADDRESS="$2"
    shift 2
    ;;
  *)
    wrong_arg "$1"
    break
    ;;
esac
done

# Getting master private ip address
info "Getting private ip address"
_SUBNET=$(echo $PEER_SUBNET|cut -d "." -f1-3)
PEER_ADDRESS=$(ip -4 a |grep $_SUBNET |awk -F "inet |/" '{ print $2 }')
info "Peering address for master is: "$PEER_ADDRESS

# Fix kubelet IP for vagrant
info "Fix kubelet IP for vagrant"
info "Worker address is: "$WORKER_ADDRESS
sed -i '3s/^/Environment="KUBELET_EXTRA_ARGS=--node-ip='"$WORKER_ADDRESS"'"\n/' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Restart kubelet with fix IP for vagrant and Flannel Pod network
info "Restart kubelet with fix IP for vagrant and Flannel Pod network"
systemctl daemon-reload
systemctl restart kubelet

# Node try to join the cluster on master Kubernetes
info "Node try to join the cluster on master Kubernetes"
while [ ! -f /vagrant/join.txt ]; do
  sleep 5
done

JOIN_COMMAND=$(cat /vagrant/join.txt)
$JOIN_COMMAND

info "Node joined cluster!"
