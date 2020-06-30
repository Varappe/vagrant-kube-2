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

wrong_arg(){
 error "Invalid parameter for $1"
 exit "1"
}

while [ $# -gt 0 ]; do
case "$1" in
  -s|--node_ip)
    NODE_ADDRESS="$2"
    shift 2
    ;;
  -s|--node_name)
    NODE_NAME="$2"
    shift 2
    ;;
  *)
    wrong_arg "$1"
    break
    ;;
esac
done

# Install kubeadm: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#control-plane-node-s
## Letting iptables see bridged traffic
info "Letting iptables see bridged traffic"
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

## Installing runtime
### Install Docker CE
#### Uninstall old versions
info "Uninstall old docker versions"
apt-get remove -y docker docker-engine docker.io containerd runc

#### Set up the repository:
##### Install packages to allow apt to use a repository over HTTPS
info "Install packages to allow apt to use a repository over HTTPS"
apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y \
  apt-transport-https ca-certificates curl software-properties-common gnupg2

##### Add Docker official GPG key
info "Add Docker official GPG key"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

##### Add Docker apt repository
info "Add Docker apt repository"
add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

#### Install Docker CE
info "Install Docker CE"
apt-get update \
  && apt-get install -y \
  containerd.io=1.2.13-1 \
  docker-ce=5:19.03.8~3-0~ubuntu-$(lsb_release -cs) \
  docker-ce-cli=5:19.03.8~3-0~ubuntu-$(lsb_release -cs)

##### Setup docker daemon to use cgroup driver systemd and not cgroupfs
info "Setup docker daemon to use cgroup driver systemd and not cgroupfs"
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

##### Restart docker
systemctl daemon-reload
systemctl restart docker

##### Add vagrant user to docker group
info "Add vagrant user to docker group"
usermod -aG docker "vagrant"

## Installing kubeadm, kubelet and kubectl
info "Installing kubeadm, kubelet and kubectl"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
swapoff -a
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

### Install kebectl and kubeadm completion
info "Install kebectl and kubeadm completion"
mkdir /home/vagrant/.kube
kubectl completion bash > kubectl
mv kubectl /etc/bash_completion.d/
kubeadm completion bash > kubeadm
mv kubeadm /etc/bash_completion.d/

### Setup kubelet daemon to use cgroup driver systemd and not cgroupfs
info "Setup kubelet daemon to use cgroup driver systemd and not cgroupfs"
cat > /etc/default/kubelet <<EOF
KUBELET_EXTRA_ARGS=--cgroup-driver=systemd
EOF

### Restart kubelet
systemctl daemon-reload
systemctl restart kubelet

## Fix hostname IP address and Kubeadm cidr service routage
info "Fix hostname IP address and Kubeadm cidr service routage"
### Fix /etc/hosts
info "Fix /etc/hosts: sed -i 's/127.0.1.1\t'"$NODE_NAME"'/'"$NODE_ADDRESS"'\t'"$NODE_NAME"'/' /etc/hosts"
sed -i 's/127.0.1.1\t'"$NODE_NAME"'/'"$NODE_ADDRESS"'\t'"$NODE_NAME"'/' /etc/hosts
### Add cidr routage in /etc/netplan/60-routes.yaml
cat > /etc/netplan/60-routes.yaml <<EOF
---
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s8:
      routes:
      - to: 10.96.0.0/12
        via: $NODE_ADDRESS
EOF
netplan apply

## kube-proxy IPVS required kernel modules
info "kube-proxy IPVS required kernel modules"
modprobe ip_vs_wrr
modprobe ip_vs_rr
modprobe ip_vs_sh
modprobe ip_vs

### Packages ipset should be installed on the node before using IPVS mode
apt-get install -y ipset ipvsadm
