## 下载最新的安装包，并上传至服务器
- https://download.docker.com/linux/rhel/8/x86_64/stable/Packages/containerd.io-2.2.1-1.el8.x86_64.rpm
## 升级并重启containerd
~~~
rpm -Uvh containerd.io-2.2.1-1.el8.x86_64.rpm
systemctl restart containerd
containerd -version
~~~
