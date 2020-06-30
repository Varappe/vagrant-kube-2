# -*- mode: ruby -*-
# vi: set ft=ruby :


# Config parameters
$image_version = "ubuntu/bionic64"
$enable_serial_logging = false
$vm_gui = false
$vm_memory_master = ENV.fetch('VAGRANT_MASTER_RAM', 4096)
$vm_memory_worker = ENV.fetch('VAGRANT_WORKER_RAM', 4096)
$vm_cpus_master = ENV.fetch('VAGRANT_MASTER_CPU', 4)
$vm_cpus_worker = ENV.fetch('VAGRANT_WORKER_CPU', 4)
$default_subnet = ENV.fetch('VAGRANT_SUBNET', '192.168.66.0')
$default_workers = ENV.fetch('VAGRANT_WORKERS', 2).to_i
$subnet_ip = "#{$default_subnet.split(%r{\.\d*$}).join('')}"
$master_ip = $subnet_ip + ".2"

Vagrant.configure("2") do |config|
# Vagrant proxy
  if Vagrant.has_plugin?("vagrant-proxyconf")
    config.proxy.http     = "http://proxy.rd.francetelecom.fr:8080"
    puts "http_proxy: " + config.proxy.http
    config.proxy.https    = "http://proxy.rd.francetelecom.fr:8080"
    puts "https_proxy: " + config.proxy.https
    config.proxy.ftp      = "http://proxy.rd.francetelecom.fr:8080"
    puts "ftp_proxy: " + config.proxy.ftp
    # localhost,127.0.0.0/8,[CNI network, CIDR Flannel network and cluster IP Kubernetes and future installations], docker poll in VMs, Kubernetes subnet
    config.proxy.no_proxy = "localhost,127.0.0.0/8,10.0.0.0/8,172.17.0.0/16,192.168.0.0/16"
    puts "no_proxy: " + config.proxy.no_proxy
  end

# Master
  config.vm.define "master" do |master_conf|
    master_conf.vm.box = $image_version
    master_conf.vm.provider :virtualbox do |v|
       v.check_guest_additions = false
    end
    master_conf.vm.hostname = "master"
    master_conf.vm.provider :virtualbox do |vb|
      vb.gui = $vm_gui
      vb.memory = $vm_memory_master
      vb.cpus = $vm_cpus_master
    end
    master_conf.vm.network :private_network, ip: $master_ip
    master_conf.vm.provision :shell, :path => "common.sh", :args => ["--node_ip", $master_ip, "--node_name", "master"]
    master_conf.vm.provision :shell, :path => "master.sh", :args => ["--subnet", $subnet_ip]
  end

# Worker config
  (1..$default_workers).each do |i|
    config.vm.define "worker-#{i}" do |worker_conf|
      worker_conf.vm.box = $image_version
      worker_conf.vm.provider :virtualbox do |v|
        v.check_guest_additions = false
      end
      worker_conf.vm.hostname = "worker-#{i}"
      worker_conf.vm.provider :virtualbox do |vb|
        vb.gui = $vm_gui
        vb.memory = $vm_memory_worker
        vb.cpus = $vm_cpus_worker
      end
      $ip = $subnet_ip + "." + "#{i+4}"
      worker_conf.vm.network :private_network, ip: $ip
      worker_conf.vm.provision :shell, :path => "common.sh", :args => ["--node_ip", $ip, "--node_name", "worker-#{i}"]
      worker_conf.vm.provision :shell, :path => "worker.sh", :args => ["--subnet", $subnet_ip, "--node_ip", $ip]
    end
  end
end

