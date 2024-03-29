#!/bin/bash
#0 - Disable swap, swapoff then edit your fstab removing any entry for swap partitions
swapoff -a

#0 - Install Packages 
#containerd prerequisites, and load two modules and configure them to load on boot
#https://kubernetes.io/docs/setup/production-environment/container-runtimes/
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

#Install containerd
sudo apt-get update 
sudo apt-get install -y containerd


#Create a containerd configuration file
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml


sudo sed -i 's/            SystemdCgroup = false/            SystemdCgroup = true/' /etc/containerd/config.toml

#Restart containerd with the new configuration
sudo systemctl restart containerd

#Install Kubernetes packages - kubeadm, kubelet and kubectl
#Add Google's apt repository gpg key
# sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg

#Add the Kubernetes apt repository
#echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
#echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

#Update the package list and use apt-cache policy to inspect versions available in the repository
sudo apt-get update
apt-cache policy kubelet | head -n 20 


#Install the required packages, if needed we can request a specific version. 
#Use this version because in a later course we will upgrade the cluster to a newer version.
#Try to pick one version back because later in this series, we'll run an upgrade
VERSION=1.24.3-00
sudo apt-get install -y kubelet=$VERSION kubeadm=$VERSION kubectl=$VERSION
sudo apt-mark hold kubelet kubeadm kubectl containerd


#To install the latest, omit the version parameters
#sudo apt-get install kubelet kubeadm kubectl
#sudo apt-mark hold kubelet kubeadm kubectl containerd

#Ensure both are set to start when the system starts up.
sudo systemctl enable kubelet.service
sudo systemctl enable containerd.service
