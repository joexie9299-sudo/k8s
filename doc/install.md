### K8S部署  https://cloud.tencent.com/developer/article/2347138、https://xie.infoq.cn/article/08ed85399b0d1fcc322056f2e
### HELM https://helm.sh/zh/docs/intro/install/
### 安装网络组件 https://docs.projectcalico.org/v3.20/manifests/calico.yaml?spm=a2c6h.12873639.article-detail.5.5241293a2EScmq&file=calico.yaml
- curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml -O kubectl apply -f calico.yaml
- kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/crds.yaml
### 安装dashboard https://kubernetes.io/zh-cn/docs/tasks/access-application-cluster/web-ui-dashboard/
### METALB https://www.lixueduan.com/posts/cloudnative/01-metallb/
### kubeadm安装 https://v1-34.docs.kubernetes.io/zh-cn/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
### container https://cloud.tencent.com/developer/article/2129850
### 新增Node节点 https://kubernetes.io/zh-cn/docs/tasks/administer-cluster/kubeadm/adding-linux-nodes/
### 离线安装 https://blog.csdn.net/wx370092877/article/details/129980718
### 安装containerd
### 安装 ollama https://kubesphere.io/zh/blogs/deploy-ollama-on-kubesphere/
### 显卡驱动 https://www.nvidia.com/en-us/drivers/details/259242/
### 容器管理 https://cloud.tencent.com/developer/article/2308391
### GPU https://www.cnblogs.com/kubesphere/p/18293490
55.192.0.125 master
55.192.0.7 node1
55.192.0.159 node2
55.189.0.73 node3_gpu


55.192.0.159 master


deb https://mirror.tuna.tsinghua.edu.cn/ubuntu-ports/ focal main restricted universe multiverse
deb https://mirror.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-updates main restricted universe multiverse
deb https://mirror.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-backports main restricted universe multiverse
deb https://mirror.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-security main restricted universe multiverse
deb https://mirror.tuna.tsinghua.edu.cn/ubuntu-ports/ focal-proposed main restricted universe multiverse




1. sudo hostnamectl set-hostname node3_gpu
2. 修改host配置
   3. vim /etc/hosts
      4. 55.192.0.125 master
         55.192.0.7 node1
         55.192.0.159 node2
         55.189.0.73 node3_gpu
5. 禁用swap
   6. sudo swapoff -a
      sudo sed -i '/ swap / s/^(.*)$/#1/g' /etc/fstab