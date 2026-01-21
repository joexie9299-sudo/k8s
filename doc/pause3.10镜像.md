## 下载镜像包
- https://app-center-9a80a0dd892e4a7085270719d64e89c3.obs.ap-southeast-1.myhuaweicloud.com:443/k8s-pause.tar?AccessKeyId=HPUA7USXCYBYESN2UX28&Expires=1799655675&Signature=S03ecUMD9lzY/7dZqqIn78p7iCk%3D
~~~
# 上传至所有节点
# 导入本地镜像库
ctr -n k8s.io images import k8s-pause.tar
~~~