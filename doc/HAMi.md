## HAMi：异构AI计算虚拟化中间件

异构AI计算虚拟化中间件（HAMi），前身为k8s-vGPU-scheduler，是一个专为管理k8s集群中异构AI计算设备而设计的"一体化"Helm Chart。它能够实现异构AI设备在多个任务间的共享能力。

## 为什么选择HAMi

- **设备共享**
  - 支持多种异构AI计算设备（如NVIDIA GPU/CUDA）
  - 支持多设备容器的设备共享
- **设备内存控制**
  - 容器内硬性内存限制
  - 支持动态设备内存分配
  - 支持按MB或百分比分配内存
- **设备规格指定**
  - 支持指定特定类型的异构AI计算设备
  - 支持通过设备UUID指定具体设备
- **开箱即用**
  - 对容器内任务透明无感
  - 通过helm一键安装/卸载，简洁环保
- **开放中立**
  - 由互联网、金融、制造业、云服务商等多领域联合发起
  - 以CNCF开放治理为目标



## 参考文档

- https://project-hami.io/zh/docs/userguide/configure
- https://aws.amazon.com/cn/blogs/china/gpu-virtualization-practice-based-on-hami/



## （Master执行）删除GPU Operator Nvidia-device

~~~
# 删除operator device plugin 避免冲突
kubectl delete daemonset nvidia-device-plugin-daemonset -n gpu-operator
~~~



## 安装HAMI

获取安装文件：https://app-center-9a80a0dd892e4a7085270719d64e89c3.obs.ap-southeast-1.myhuaweicloud.com:443/hami.tar.gz?AccessKeyId=HPUA7USXCYBYESN2UX28&Expires=1800091335&Signature=Kn%2Byjvo4PTKhOOBnb7yarwo5BKI%3D

~~~
# （Master And Woker）将文件移动至data目录下
mv hami.tar.gz /data

# （Master And Woker）解压缩
cd /data
tar zxvf hami.tar.gz
cd /data/hami

# （Master And Woker）导入镜像
ctr -n k8s.io images import hami-images.tar
ctr -n k8s.io images import scheduler-images.tar
ctr -n k8s.io images import docker-kube-webhook-certgen-images.tar
ctr -n k8s.io images import ghcr-kube-webhook-certgen-images.tar

# （Master）给GPU Woker Node打上标签
kubectl label nodes <nodeName> gpu=on

# （Master）安装
helm install hami ./hami-2.8.0.tgz --namespace kube-system

# （Master）查看状态(确认状态为RUNNING)
kubectl get pod -n kube-system | grep hami
~~~



## 配置说明

- 官方说明文档：https://project-hami.io/zh/docs/userguide/configure

~~~
# NVIDIA GPU 相关配置
nvidia:
  # 显存虚拟化比例 (1.0 = 不超分配, >1.0 = 超分配)
  deviceMemoryScaling: 1.0
  # 每个GPU最大任务数 (与deviceSplitCount相关，=2 表明每个GPU分割成2个vGPU，即允许两个task在同一GPU运行)
  deviceSplitCount: 2
  # MIG策略 ("none" = 忽略MIG, "mixed" = 使用MIG)
  migstrategy: "none"
  # 是否禁用算力限制 ("false" = 启用限制, "true" = 禁用限制，结合项目需求多个task要默认共享GPU的全部算力，因此这里选择true。如果你的项目中需要做算力的分配和隔离则应该选择false，即启用限制)
  disablecorelimit: "true"
  # 默认显存分配 (MB, 0 = 使用100%显存)
  defaultMem: 0
  # 默认GPU核心百分比 (0-100, 0 = 自动分配, 100 = 独占整卡，结合项目需求多任务需要显存隔离，但GPU资源共享，所以这里设置0即不做GPU资源隔离和预留)
  defaultCores: 0
  # 默认GPU数量，申请资源时未指定GPU数量即默认为1
  defaultGPUNum: 1
~~~

- （master执行）修改配置方式：

~~~
# 如何修改配置，找到对应的关键词，按需调整
kubectl edit configmap hami-scheduler-device -n kube-system

# 调整后需要重启相关应用
# 重启 HAMi 的 Device Plugin DaemonSet
kubectl rollout restart daemonset hami-device-plugin -n kube-system
# 重启 hami 的 Scheduler（如果此处新的pod一直是pending状态，请执行 kubectl delete pod <POD-NAME> -n kube-system 删除旧的pod）
kubectl rollout restart deployment hami-scheduler -n kube-system

# 查看node可被分配的gpu数目(Allocatable部分)
kubectl describe node <gpu-node-name>
~~~



## 调度说明

- 官方文档参考：https://project-hami.io/zh/docs/userguide/NVIDIA-device/specify-device-core-usage
- 官方示例：https://github.com/Project-HAMi/HAMi/tree/master/examples/nvidia



## （master）调度验证

~~~
# 执行
kubectl apply -f /data/hami/test-v-gpu.yaml

## 查看POD状态,Completed表示成功
kubectl get pod | grep gpu-test-pod

## 查看POD日志，检查输出的GPU是否与yaml文件内指定的一致
kubectl logs gpu-test-pod

## 清理
kubectl delete -f /data/hami/test-v-gpu.yaml
~~~

