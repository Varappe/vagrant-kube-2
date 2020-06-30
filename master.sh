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

# Initializing kubeadm
info "Initializing kubeadm with --pod-network-cidr=10.244.0.0/16 for Flannel driver"
info "WARNING: kubeadm init can not be performed with --feature-gates=SupportIPVSProxyMode=true (deprecated). If you want proxy mode IPVS instead of iptable after init edit kube-proxy and set mode=ipvs:"
info "kubectl edit configmap kube-proxy -n kube-system - change mode from "" to ipvs - kill any kube-proxy pods : kubectl get pods -n kube-system and kubectl delete pods -n kube-system <pod-name>"
kubeadm init --apiserver-advertise-address=$PEER_ADDRESS --pod-network-cidr=10.244.0.0/16

# Add credentials to root .kube folder to permit root to use kubectl
info "Add credentials to root .kube folder to permit root to use kubectl"
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

# Copy credentials to vagrant .kube folder to permit vagrant to use kubectl
info "Copy credentials to vagrant .kube folder to permit vagrant to use kubectl"
mkdir -p /home/vagrant/.kube
cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config

# Fix kubelet IP for vagrant
info "Fix kubelet IP for vagrant"
sed -i '3s/^/Environment="KUBELET_EXTRA_ARGS=--node-ip='"$PEER_ADDRESS"'"\n/' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Fix Flannel Pod network add-on configuration for vagrant and installing it
info "Fix Flannel Pod network add-on configuration for vagrant and installing it"
curl -o kube-flannel.yml https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
sed -i.bak 's/- --kube-subnet-mgr/&\n        - --iface=enp0s8/g' kube-flannel.yml
info "Installing Flannel Pod network add-on on the cluster of master Kubernetes"
kubectl create -f kube-flannel.yml

# Restart kubelet with fix IP for vagrant and Flannel Pod network
info "Restart kubelet with fix IP for vagrant and Flannel Pod network"
systemctl daemon-reload
systemctl restart kubelet

# Setting the join command for nodes
info "Setting the join command for nodes"
JOIN_TOKEN=$(kubeadm token list |tail -n -1| awk '{ print $1 }')
JOIN_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
JOIN_COMMAND="kubeadm join "$PEER_ADDRESS":6443 --token "$JOIN_TOKEN" --discovery-token-ca-cert-hash sha256:"$JOIN_HASH

info "In order to join the cluster, run this command on nodes: "
info "$JOIN_COMMAND"
echo $JOIN_COMMAND > /vagrant/join.txt


