# 部署MetalLB

物料下载：https://app-center-9a80a0dd892e4a7085270719d64e89c3.obs.ap-southeast-1.myhuaweicloud.com:443/vllm/metallb.tar.gz?AccessKeyId=HPUA7USXCYBYESN2UX28&Expires=1800611692&Signature=Hbbm4vT00Co46QlajNqIFkdDhoY%3D

~~~
# (master AND woker)移动至目录
mv metallb.tar.gz /data

# (master AND woker)解压缩
tar zxvf metallb.tar.gz

# (master AND woker)进入目录
cd metallb

# (master AND woker)导入离线镜像
ctr -n k8s.io images import /data/metallb/images/metallb-speaker.tar
ctr -n k8s.io images import /data/metallb/images/metallb-controller.tar

# (master)安装
kubectl apply -f /data/metallb/metallb-native.yaml

# (master)确认POD都正常运行
kubectl get pod -n metallb-system

# (master)配置IP池，修改IPAddressPool.yaml内的addresses，配置为预留给metalLB可用的IP列表吗，修改后执行下面的命令应用
kubectl apply -f IPAddressPool.yaml
  
# (master)广播IP
kubectl apply -f L2Advertisement.yaml
  
# (master)修改ollama的service type为LoadBalancer
kubectl edit service ollama

# (master)修改完成后查看service的EXTERNAL-IP，通过该IP访问应用：192.168.122.125:11434
[root@master1 metallb]# kubectl get service
NAME             TYPE           CLUSTER-IP     EXTERNAL-IP       PORT(S)           AGE
ollama           LoadBalancer   10.100.8.223   192.168.122.125   11434:31434/TCP   52m
~~~

