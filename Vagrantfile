# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/bionic64"

  config.vm.hostname = "servidor.local"
  config.vm.network "private_network",
    ip: "192.168.10.100"

  config.vm.synced_folder ".", "/vagrant",
    disabled: true

  config.vm.synced_folder ".", "/var/servidor",
    create: true, owner: "vagrant", group: "www-data",
    mount_options: ["dmode=775,fmode=664"]

  config.vm.provider "virtualbox" do |vb|
    vb.name = "servidor-dev"
    vb.linked_clone = true
    vb.memory = "1024"
  end

  config.vm.provision :shell, path: "vagrant/bootstrap.sh"

end