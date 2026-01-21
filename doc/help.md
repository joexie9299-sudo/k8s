### K8S基本概念介绍

#### Node

#### Pod

#### Service

### K8S简单使用（各类YAML简单编写）

### 后续规划

#### 添加Master节点

    # 在Master节点执行以下命令，

    

    # 

    kubeadm join 55.192.0.159:6443 --token ho8jvb.q5njhyvwfdbkk3f2 --discovery-token-ca-cert-hash sha256:16a7e60868d8a017de61e32e7aa45adf46343befd14d21fed3fe316999c66b1e --certificate-key 42a5938e7308a7cf7cd1fd26b259357b52bbf8fa2ec903701c08d0e47da86d8d --control-plane

### GPU节点调度

前提：按照普通节点的方式Join至集群内

#### 安装GPU驱动

    # 安装编译工具和依赖
    sudo dnf install -y gcc make kernel-devel kernel-headers

    # 下载并安装驱动
    wget https://us.download.nvidia.com/XFree86/Linux-x86_64/550.54.14/NVIDIA-Linux-x86_64-550.54.14.run
    chmod +x NVIDIA-Linux-x86_64-550.54.14.run
    sudo ./NVIDIA-Linux-x86_64-550.54.14.run

    # 验证
    nvidia-smi

##### nvidia-container-runtime 安装并配置（https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html）

    # 配置源
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
    sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo

    # 安装
    export NVIDIA_CONTAINER_TOOLKIT_VERSION=1.18.1-1
    sudo yum install -y \
    nvidia-container-toolkit-${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    nvidia-container-toolkit-base-${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    libnvidia-container-tools-${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    libnvidia-container1-${NVIDIA_CONTAINER_TOOLKIT_VERSION}

    # 配置
    sudo nvidia-ctk runtime configure --runtime=containerd
    sudo systemctl restart containerd

#### NVIDIA GPU Operator 安装 https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html#operator-install-guide

    kubectl create ns gpu-operator
    
    kubectl label --overwrite ns gpu-operator pod-security.kubernetes.io/enforce=privileged

    helm install gpu-operator /data/k8s/heml/gpu-operator-v25.10.1.tgz --namespace gpu-operator --set driver.enabled=false

### YUM离线安装包

    sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
    yum install --downloadonly --downloaddir=/root/yum/container containerd.io.x86_64.2.2.1-1.el8 
    ## Kubernetes组件（kubelet kubeadm kubectl） 来源：https://pkgs.k8s.io/core:/stable:/v1.34/rpm/
    yum install --downloadonly --disableexcludes=kubernetes --downloaddir=/root/yum/k8s  kubelet kubeadm kubectl

    ## nvidia-container-runtime
    export NVIDIA_CONTAINER_TOOLKIT_VERSION=1.18.1-1
    sudo yum install --downloadonly --downloaddir=/root/yum/container-runtime-toolkit  \
    nvidia-container-toolkit-${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    nvidia-container-toolkit-base-${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    libnvidia-container-tools-${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
    libnvidia-container1-${NVIDIA_CONTAINER_TOOLKIT_VERSION}

    yum install --downloadonly --downloaddir=/data/k8s/yum-repo/yum/lb keepalived haproxy
    yum install -y keepalived haproxy
    rpm -ivh /data/k8s/yum-repo/yum/lb/*.rpm

### 打包容器镜像

    ## 查看依赖的镜像列表
    kubectl get pods -n kubernetes-dashboard -o yaml | grep image:
    kubectl get pods -A -o yaml | grep image:

    ## 查看yaml依赖的镜像列表
    grep -i "image:" calico.yaml

    ## 打包镜像
    ctr -n k8s.io images export all-images.tar $(ctr -n k8s.io images ls -q)
    ctr -n k8s.io images export all-images.tar docker.io/ollama/ollama:0.14.0-rc0

    
    sudo ctr -n k8s.io images  registry.k8s.io/pause:3.8
    ctr -n k8s.io images pull registry.k8s.io/pause:3.8
    ctr -n k8s.io images export k8s-pause.tar registry.k8s.io/pause:3.8
    tar -czvf k8s.tar.gz k8s

    ctr -n k8s.io images import k8s-pause.tar


ctr -n k8s.io images export hami-images.tar docker.io/projecthami/hami:v2.8.0
ctr -n k8s.io images export scheduler-images.tar registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler:v1.34.3
ctr -n k8s.io images export docker-kube-webhook-certgen-images.tar docker.io/liangjw/kube-webhook-certgen:v1.1.1
ctr -n k8s.io images export ghcr-kube-webhook-certgen-images.tar ghcr.io/jkroepke/kube-webhook-certgen:1.7.4


ctr -n k8s.io images import hami-images.tar
ctr -n k8s.io images import scheduler-images.tar
ctr -n k8s.io images import docker-kube-webhook-certgen-images.tar
ctr -n k8s.io images import ghcr-kube-webhook-certgen-images.tar


### helm离线包

    # 拉取 Chart 源码并解压
    helm pull kubernetes-dashboard/kubernetes-dashboard --untar
    # 打包成 tgz 文件
    helm package kubernetes-dashboard
    
    # 拉取指定版本的 Chart
    helm pull nvidia/gpu-operator --version v25.10.1 --untar
    # 打包 Chart
    helm package gpu-operator


ctr -n k8s.io images pull docker.io/projecthami/hami:v2.8.0
ctr -n k8s.io images pull registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler:v1.34.3