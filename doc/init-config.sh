# 解压物料包
mkdir -p /data
mv k8s.tar.gz /data
cd /data
tar zxvf k8s.tar.gz

# 解压yum包
tar zxvf /data/k8s/yum-repo/yum.tar.gz -C /data/k8s/yum-repo/

# 安装heml
cd /data/k8s/heml/
tar -zxvf helm-v3.14.4-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
helm version

#### 统一时区
# sudo timedatectl set-timezone Asia/Shanghai

#### 关闭防火墙
sudo systemctl stop firewalld
sudo systemctl disable firewalld

#### 禁用swap
sudo swapoff -a
sudo sed -i '/ swap / s/^(.*)$/#1/g' /etc/fstab

#### 修改内核参数
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
#### 修改网络参数
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

### 使上面配置生效
sudo sysctl --system

# 安装containerd start
## 移除冲突依赖（RHEL默认安装了podman，需要移除）
sudo yum --disableplugin=subscription-manager remove -y podman buildah cockpit-podman podman-catatonit

## 安装containerd
rpm -ivh /data/k8s/yum-repo/yum/container/*.rpm
containerd --version

## 配置containerd使用systemd作为cgroup
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

## 重启并设置开机自启
sudo systemctl restart containerd
sudo systemctl enable containerd

## 导入本地镜像
ctr -n k8s.io images import /data/k8s/containerd-img/master-images.tar
ctr -n k8s.io images import /data/k8s/containerd-img/woker-node-images.tar
# 安装containerd end

## 安装k8s相关组件 start
# 将 SELinux 设置为 permissive 模式（相当于将其禁用）
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# 安装 kubelet、kubeadm 和 kubectl，并启用 kubelet 以确保它在启动时自动启动:
rpm -ivh /data/k8s/yum-repo/yum/k8s/*.rpm
sudo systemctl enable --now kubelet
## 安装k8s相关组件 end


