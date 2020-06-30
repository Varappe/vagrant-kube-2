.. module:: CHANGELOG.rst
   :synopsis: vagrant-kube Changelog
.. moduleauthor:: Frederic PRADIER <frederic.pradier@orange.com>


# Changelog

This document records all notable changes to `vagrant-kube` [project](https://gitlab.forge.orange-labs.fr/Kuberbetes-solution/vagrant-kube).
This project adheres to [Semantic Versioning](http://semver.org/).

This project is based on Sofiane IMADALI `vagrant-kube` [project](https://github.com/sofianinho/vagrant-kube).

# dev (unreleased)

**Added**:

- Kubernetes Dashboard
- MetalLB to expose external IP address for Kubernetes services in `LoadBalancer` mode : 240 addresses 
- Apache2 reverse proxy to give Internet access for Kubernetes services
- "docs" directory with French instructions and details
- Packages for IPVS

**Changed:**

- Address for master node and address range for workers nodes 

**Deprecated:** None

**Removed:** None

**Fixed:** None

**Security:** None

# Release 2.1

**Added**:

- Communication between VMs cluster and nodes: see Fixed section
- Kernel modules for IPVS. Iptables by default. If you need IPVS you need to activate it in kube-proxy configmap and restart all kube-proxy pods for apply

**Changed:** None

**Deprecated:** None

**Removed:** None

**Fixed:**

- Fix kubelet IP for vagrant
- Fix Flannel Pod network add-on configuration for vagrant and installing it
- Fix /etc/hosts
- Fix Kubeadm cidr service routing

**Security:** None

# Release 2.0

**Added**:

- README.md section:
    - "Host prerequisite": Proxy environment, DNS, Packages, Vagrant proxy
    - "Stop vagrant-kube"
    - Delete vagrant-kube VMs
    - "Remove Virtualbox network interface"

- CHANGELOG.md file

**Changed:**

- common.sh:
    - Update all procedure
    - Setup docker and kubelet daemon to use cgroup driver systemd and not cgroupfs
    - Letting iptables see bridged traffic  
    - add "vagrant" user to docker group
- master.sh:
    - Remove `kubectl taint nodes --all node-role.kubernetes.io/master-` to have Control plane node isolation
- README.md section:
    - "Use"
    - "Interact with the cluster remotely (from host)"

**Deprecated:** None

**Removed:** None

**Fixed:**

- Master resources attribution in Vagrantfile
- Pod network Driver for master to communicate with workers 

**Security:** None