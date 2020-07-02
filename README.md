# Kubernetes cluster with vagrant and kubeadm

Simple vagrantfile for any sized cluster (master + workers) in Ubuntu 18.04 VMs. Very configurable through 2 env variables.

This project is based on Sofiane IMADALI `vagrant-kube` [project](https://github.com/sofianinho/vagrant-kube).
The goal of this project is to add host prerequisite for proxy environment, DNS, packages needed, Kubernetes Dashboard, MetalLB, reverse proxy,... 

## Note
Nodes (can be modify in Vagrantfile):
- 1 master subnet.2
- 10 workers from subnet.5 to subnet.14 (2 by default)

Services (can be modify and upgrade in metallb-config.yaml):
- 240 services with external IP address from subnet.15 to subnet.254

For a README in French see [Kubernetes quick start - GitHub vagrant-kube-2 - V0.0.pdf](docs/Kubernetes_quick_start_-_GitHub_vagrant-kube-2_-_V0.0.pdf)

## Host prerequisite
### Session Proxy environment
If you have a proxy you needs to configure it and exclude your vagrants machine to it. 
See your current environment proxy configuration:
```
env | grep proxy
```

For `no_proxy` you need to exclude:
- Your dockers networks: 172.0.0.0/8
- Kubernetes subnet: 192.168.0.0/16

Example proxy configuration:
```
export {http,https,ftp}_proxy='http://<your proxy URL>:<your proxy port>'
export {HTTP,HTTPS,FTP}_PROXY='http://<your proxy URL>:<your proxy port>'
export {no_proxy,NO_PROXY}='localhost,127.0.0.0/8,<network domain name>,<....>,172.0.0.0/8,192.168.0.0/16'
```

### DNS
The `resolvconf` program automatically generates and overwrites the `/etc/resolv.conf` file.

DNS configuration is done in the `/etc/network/interfaces` file:

```
cd /etc/network
sudo vi interfaces

# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eno1
iface eno1 inet static
        address <server IP adresse>
        netmask 255.255.255.0
        network <network address>
        broadcast <broadcast address>
        gateway <gateway address>
        # dns-* options are implemented by the resolvconf package, if installed
        dns-nameservers <DNS 1 address> <DNS 2 address> <…>
        dns-search <domaine name>
```

Apply DNC configuration:
```
sudo systemctl restart networking
```

Check that the configuration appears in the `/etc/resolv.conf` file.

### Packages
You need virtualbox and vagrant packages:
```
apt-get update
apt-get upgrade
apt-get install virtualbox vagrant
```

You need `kubectl`. Verify:
```
kubectl version --client
```

If not installed, install it:
```
sudo apt-get update && sudo apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl
```
For more details see [Kubernetes documentation](https://kubernetes.io/fr/docs/tasks/tools/install-kubectl/). 

## Vagrant proxy

If you have a proxy you needs to install `vagrant-proxyconf`
```
vagrant plugin install vagrant-proxyconf
```

### Vagrant proxy configuration
There many options to configure it. I choose to configure Vagrant proxy in `Vagrantfile`.
For `no_proxy` you need to exclude network:
- Kubernetes clusters: `10.96.0.0/12`
- CNI and CIDR Flannel: `10.244.0.0/16`
- Others future clusters installations: `10.0.0.0/8`
- Docker in VMs: `172.17.0.0/16`
- Kubernetes subnet: `192.168.0.0/16`

```
...
Vagrant.configure("2") do |config|
# Vagrant proxy
  if Vagrant.has_plugin?("vagrant-proxyconf")
    config.proxy.http     = "http://<your proxy URL>:<your proxy port>"
    puts "http_proxy: " + config.proxy.http
    config.proxy.https    = "http://<your proxy URL>:<your proxy port>"
    puts "https_proxy: " + config.proxy.https
    config.proxy.ftp      = "http://<your proxy URL>:<your proxy port>"
    puts "ftp_proxy: " + config.proxy.ftp
    # localhost,127.0.0.0/8,[CNI network, CIDR Flannel network and cluster IP Kubernetes and future installations], docker poll in VMs, Kubernetes subnet
    config.proxy.no_proxy = "localhost,127.0.0.0/8,10.0.0.0/8,172.17.0.0/16,192.168.0.0/16"
    puts "no_proxy: " + config.proxy.no_proxy
  end
...
```

## Use

## Full list of possible configurations

| Variable        | Definition           | Minimum recommended | Default  | Example value |
| :-------------: |:-------------:| :-----:|:------:|:------:|
| `VAGRANT_SUBNET`| Private subnet for VMs where the cluster is formed and peered. <br> Master is at .2 and Workers start at .5 |  | `192.168.66.0` |`192.168.178.0`, `10.10.0.0`|
| `VAGRANT_WORKERS`      | Number of workers in the cluster (master is also a worker)      | 1 | 2 | 5|
| `VAGRANT_MASTER_RAM` | Memory for the master      | 2048 | 4096 | 4096, 1024 |
| `VAGRANT_MASTER_CPU` | Number of CPUs for the master      | 2 | 4 | 2 |
| `VAGRANT_WORKER_RAM` | Memory per worker      | 2048 | 4096 | 4096, 1024 |
| `VAGRANT_WORKER_CPU` | Number of CPUs for per worker      | 2 | 4 | 2 |


Verify that the subnet you want to use for Kubernetes is not already in use on the host server:
```
ip a
```

Modify default configuration in file `Vagrantfile` with your values:
```
vi Vagrantfile
```

Create VMs nodes and start Kubernetes:
```
vagrant up
```

## Interact with the cluster remotely (from host)

For that, I find the simplest way is to copy your cluster `config` file outside of the master vm and use kubectl with `--kubeconfig` flag or export `KUBECONFIG` environment variable with `config` file.  

Copy `config` file in your host with ssh:
```
ssh vagrant@192.168.66.2 -i .vagrant/machines/master/virtualbox/private_key sudo cat /etc/kubernetes/admin.conf > config
```

Or from master VM:
```sh
vagrant ssh master
cp .kube/config /vagrant
exit
```

Export `KUBECONFIG` environment variable in host with "config" file:
```
export KUBECONFIG=$KUBECONFIG:$PWD/config
```

See that the new config has been added and see that the nodes you created are visible:
```
kubectl config view
kubectl get nodes
```
To make this step more secure, follow instructions from [here](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/) and this [cheatsheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/#kubectl-context-and-configuration).

## Expose Kubernetes services to host server
I choose to give external IP address to expose services with MetalLB solution.

### IPVS mode for Kubernetes proxy
MetalLB need Kubernetes proxy in mode IPVS and not iptables. All you need (kernel modules and packages) is already installed in clusters:
```
kubectl edit configmap -n kube-system kube-proxy
```

To have **`strictARP: true`** and **`mode: ipvs`**:
```
...
    ipvs:
      excludeCIDRs: null
      minSyncPeriod: 0s
      scheduler: ""
      strictARP: true
      syncPeriod: 0s
      tcpFinTimeout: 0s
      tcpTimeout: 0s
      udpTimeout: 0s
    kind: KubeProxyConfiguration
    metricsBindAddress: ""
    mode: ipvs
...
```

Delete all kube-proxy Pods to apply changes:
```
kubectl get pods -n kube-system
kubectl delete pods -n kube-system <kube-proxy pod-name>
```

Verify:
```
kubectl get pods -n kube-system
kubectl logs –n kube-system <kube-proxy pod-name> | grep "Using ipvs Proxier"

kubectl logs -n kube-system kube-proxy-bp6zf | grep "Using ipvs Proxier"
I0605 22:46:32.867568       1 server_others.go:259] Using ipvs Proxier.
```

### Install MetalLB
Installation:
```
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml

# On first install only for RBAC authentification
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
```
#### Configure MetalLB
I choose to use mode Layer 2 to configure IP pool. For more expositions you can choose BGP mode but you will need to create a BGP router in VM.
Change `metallb-config.yaml` file with your VAGRANT_SUBNET and the range you want to expose:
```
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.66.15-192.168.66.254
```

Apply your IP pool:
```
kubectl apply -f metallb-config.yaml
```

## Kubernetes Dashboard
For details see: 
- [https://kubernetes.io/fr/docs/tasks/access-application-cluster/web-ui-dashboard/](https://kubernetes.io/fr/docs/tasks/access-application-cluster/web-ui-dashboard/)
- [https://github.com/kubernetes/dashboard](https://github.com/kubernetes/dashboard)
- [https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md](https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md)
- [https://github.com/kubernetes/dashboard/tree/master/docs/user/accessing-dashboard](https://github.com/kubernetes/dashboard/tree/master/docs/user/accessing-dashboard)

### Deploy Dashboard
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended.yaml
```

#### Create API token Kubernetes
Create a Service Account and ClusterRoleBinding:
```
kubectl apply -f serviceaccount.yaml
kubectl apply -f dashboard-adminuser.yaml
```

Getting Bearer Token:
```
kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
```
You need this Token to logging in Kubernetes Dashboard.

#### Change Kubernetes Dashboard mode
MetalLB gives an external IP to services to `LoadBalancer` services.
Change Kubernetes Dashboard service mode:
```
kubectl edit svc kubernetes-dashboard -n kubernetes-dashboard
```

To have **`type: LoadBalancer`**:
```
...
spec:
  clusterIP: 10.110.148.73
  ports:
  - port: 443
    protocol: TCP
    targetPort: 8443
  selector:
    k8s-app: kubernetes-dashboard
  sessionAffinity: None
  type: LoadBalancer
...
```

Verify:
```
kubectl get svc -n kubernetes-dashboard

NAME                        TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)         AGE
dashboard-metrics-scraper   ClusterIP      10.108.13.231   <none>           8000/TCP        4d16h
kubernetes-dashboard        LoadBalancer   10.101.36.163   192.168.66.15    443:32347/TCP   4d16h
```
Kubernetes Dashboard is accessible from the host server with the URL: [https://192.168.66.15:443/]

Use the previously generated Token to logging in Kubernetes Dashboard.

## Give an Internet access to Kubernetes Dashboard
I use private addresses for external IP address services. I choose to use an reverse proxy to give access to services from the Internet.

### Apache2 server
Install apache2 and openssl for https:
```
sudo apt-get update
sudo apt-get install apache2 openssl
```

Generate certificate:
```
# Generate private key
sudo openssl genrsa -aes256 -out certificat.key 4096

# Unlock private key to use it with apache2
sudo mv certificat.key certificat.key.lock
sudo openssl rsa -in certificat.key.lock -out certificat.key

# Generate signature request file
sudo openssl req -new -key certificat.key.lock -out certificat.csr


# Generate certificate
openssl x509 -req -days 365 -in certificat.csr -signkey certificat.key.lock -out certificat.crt
```

Now you have:
- Private key: certificat.key
- Locked private key: certificat.key.lock
- Signature request file: certificat.csr
- Certificate : certificat.crt

Active apache2 modules for reverse proxy and SSL:
```
sudo a2enmod proxy proxy_http ssl
sudo systemctl restart apache2
```

Configure Kubernetes Dashboard reverse proxy:
```
cd /etc/apache2/sites-available
sudo vi https-<host server URL>.conf

<VirtualHost *:443>
    ServerName kubernetes.<host server URL>
    ServerAlias www.kubernetes.<host server URL>
    ServerAdmin <administrator email address>

    # Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
    # error, crit, alert, emerg.
    # It is also possible to configure the loglevel for particular
    # modules, e.g.
    # LogLevel info ssl:warn
    ErrorLog ${APACHE_LOG_DIR}/https_error.log
    CustomLog ${APACHE_LOG_DIR}/https_access.log combined

    # Activation de SSL pour le trafic entrant, cas dans le cas d'un
    # serveur web classique.
    SSLEngine On
    SSLCertificateFile    /etc/ssl/apache2/certificat.crt
    SSLCertificateKeyFile /etc/ssl/apache2/certificat.key

    # Activation de SSL pour la communication avec les backends.
    SSLProxyEngine          On
    SSLProxyVerify          none
    SSLProxyCheckPeerCN     off
    SSLProxyCheckPeerName   off
    SSLProxyCheckPeerExpire off

    # Configuration classique du mod_proxy, mis a part qu'on specifie bien
    # https dans l'URL du backend.
    ProxyRequests     Off
    ProxyPreserveHost On

    ## Kubernetes
    ProxyPass / https://192.168.66.15:443/
    ProxyPassReverse / https://192.168.66.15:443/
</VirtualHost>
```

Enable your configuration:
```
sudo a2ensite https-<host server URL>.conf
sudo systemctl restart apache2
```
Kubernetes Dashboard is accessible from Internet with the URL: `https://kubernetes.<host server URL>/`

Use the previously generated Token to logging in Kubernetes Dashboard.

## Vagrant and Virtualbox administration
Go to the `vagrant` directory to use those commands.
### Start vagrant VMs
Start VMs and if necessary create its:
```
vagrant up
```

### Status of vagrant VMs
```
vagrant status
```

### Stop vagrant VMs
```
vagrant halt
```

### Delete vagrant VMs
```
vagrant destroy
```

#### Remove Virtualbox network interface
Show Virtualbox network interface:
```
ip a | grep vboxnet
```

To remove `vboxnet0` interface:
```
VBoxManage hostonlyif remove vboxnet0
```

To remove all `vboxnet#` interface:
```
for ((i=0 ; $(ip a | grep vboxnet | wc -l) - $i ; i++)); do VBoxManage hostonlyif remove vboxnet$i ; done
```

## LICENSE
MIT
