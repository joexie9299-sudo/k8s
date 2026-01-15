# 一、下载大模型：

1. google搜索 模型名称+huggingface，点击进入
   
   ![](C:\Users\WL106242\AppData\Roaming\marktext\images\2026-01-15-11-04-31-image.png)
   
   点击Deploy左边三个点，再点击 clone repository，复制 git clone 这条命令，在这台能够联网的机器上运行。直到模型下载完。（可能花费几十分钟）
   
   ![](C:\Users\WL106242\AppData\Roaming\marktext\images\2026-01-15-11-04-05-image.png)
   
   ![](C:\Users\WL106242\AppData\Roaming\marktext\images\2026-01-15-11-03-41-image.png)
- ```git
  git clone https://huggingface.co/Qwen/Qwen3-0.6B
  ```
  
      将下载好的 Qwen3-8B文件夹整个打包，传入到服务器目录中，比如 /root/models/Qwen3-8

# 二、下载需要的镜像

下面给你一份按你们标准 **只用 ctr**、并且镜像名用 **`docker.io/vllm/vllm-openai:latest`** 的离线教程（联网机打包 → 存储介质传输 → 离线节点导入 → K8s 使用本地镜像）。

---

# vLLM 镜像离线部署教程（containerd + ctr，namespace=k8s.io）

## 目标

在可联网机器上把镜像拉下来并打包成 `tar(.gz)`，拷到离线生产节点后导入到 containerd，再让 K8s 直接使用本地镜像，不再尝试联网拉取。

---

## 0. 前置约定

* 容器运行时：**containerd**
* K8s 镜像 namespace：**k8s.io**
* 镜像：**`docker.io/vllm/vllm-openai:latest`**
* 离线文件：`vllm-vllm-openai_latest.tar.gz`（可选压缩）

---

## 1) 联网机器：拉取镜像并导出离线包

### 1.1 拉取镜像（推荐指定平台）

```bash
sudo ctr -n k8s.io images pull --platform linux/amd64 docker.io/vllm/vllm-openai:latest
```

> 如果你确定不是 amd64，可以去掉 `--platform`。但 GPU 节点一般是 amd64，这样更稳，避免拉到不需要的多架构内容。

### 1.2 确认镜像已存在 & 记录 digest（用于版本追踪）

```bash
sudo ctr -n k8s.io images ls | grep -E 'vllm|vllm-openai'
```

重点记住 `target.digest`（形如 `sha256:...`），这就是你当前“latest”实际对应的版本身份。

### 1.3 导出为 tar

```bash
sudo ctr -n k8s.io images export vllm-vllm-openai_latest.tar docker.io/vllm/vllm-openai:latest
```

### 1.4 压缩并生成校验（推荐）

```bash
gzip -1 vllm-vllm-openai_latest.tar
sha256sum vllm-vllm-openai_latest.tar.gz > vllm-vllm-openai_latest.tar.gz.sha256
```

把下面两个文件拷到移动介质：

* `vllm-vllm-openai_latest.tar.gz`
* `vllm-vllm-openai_latest.tar.gz.sha256`

---

## 2) 离线生产节点：导入镜像到 containerd（k8s.io）

把文件拷到离线节点某目录，比如 `/tmp/images/`，然后：

### 2.1 校验（推荐）

```bash
cd /tmp/images
sha256sum -c vllm-vllm-openai_latest.tar.gz.sha256
```

### 2.2 导入镜像（关键：必须是 k8s.io namespace）

```bash
gunzip -c vllm-vllm-openai_latest.tar.gz | sudo ctr -n k8s.io images import -
```

### 2.3 验证导入成功

```bash
sudo ctr -n k8s.io images ls | grep -E 'vllm|vllm-openai'
```

## 2.4 给需要使用的GPU节点打label

每个需要用到的节点，都要在master节点里 

```docker
kubectl label node gpu1 gpu=true --overwrite #gpu1为工作节点名称
```

---

## 3) K8s YAML

在K8s Deployment里上传下面这份yaml文件。(模型路径位于  /root/models/Qwen3-0.6B)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-qwen3-0p6b
  namespace: default
  labels:
    app: vllm-qwen3-0p6b
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm-qwen3-0p6b
  template:
    metadata:
      labels:
        app: vllm-qwen3-0p6b
    spec:
      nodeSelector:
        gpu: "true"
      runtimeClassName: nvidia

      volumes:
        - name: models-vol
          hostPath:
            path: /root/models
            type: ""
        - name: shm-vol
          emptyDir:
            medium: Memory
            sizeLimit: "2Gi"

      containers:
        - name: vllm
          image: docker.io/vllm/vllm-openai:latest
          imagePullPolicy: IfNotPresent

          command: ["/bin/bash", "-lc"]
          args:
            - |
              set -e
              echo "=== sanity ==="
              which vllm || true
              /usr/local/bin/vllm -v || true
              echo "=== start ==="
              exec /usr/local/bin/vllm serve /root/models/Qwen3-0.6B \
                --host 0.0.0.0 --port 8000 \
                --dtype float16 \
                --max-model-len 4096 \
                --tensor-parallel-size 1 \
                --gpu-memory-utilization 0.80 \
                --max-num-seqs 4 \
                --max-num-batched-tokens 2048 \
                --swap-space 2

          ports:
            - name: http
              containerPort: 8000
              protocol: TCP

          resources:
            requests:
              nvidia.com/gpu: "1"
              cpu: "2"
              memory: "8Gi"
            limits:
              nvidia.com/gpu: "1"
              cpu: "4"
              memory: "16Gi"

          volumeMounts:
            - name: models-vol
              mountPath: /root/models
              readOnly: true
            - name: shm-vol
              mountPath: /dev/shm

          startupProbe:
            tcpSocket:
              port: 8000
            periodSeconds: 5
            failureThreshold: 120
            timeoutSeconds: 2


          livenessProbe:
            tcpSocket:
              port: 8000
            periodSeconds: 20
            timeoutSeconds: 5
            failureThreshold: 6

          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 6
---
apiVersion: v1
kind: Service
metadata:
  name: vllm-qwen3-0p6b
  namespace: default
  labels:
    app: vllm-qwen3-0p6b
spec:
  type: NodePort
  selector:
    app: vllm-qwen3-0p6b
  ports:
    - name: http
      port: 8000
      targetPort: 8000
      nodePort: 31800
```

---

## 4) 多节点部署注意事项（非常重要）

* 如果 Pod **只会调度到 gpu1**（nodeSelector/affinity/taints 已限制），只需要在 gpu1 导入镜像。
* 如果 Pod **可能调度到多个节点**，每个节点都要重复第 2 步导入镜像，否则会出现 `ImagePullBackOff`。

---

## 5) 快速排障清单

### 5.1 Pod 报 ImagePullBackOff

1. 看 YAML 是否 `imagePullPolicy: IfNotPresent/Never`
2. 到报错的节点执行：

```bash
sudo ctr -n k8s.io images ls | grep vllm
```

没有就说明该节点没导入镜像。

### 5.2 导入了但 K8s 仍看不到

99% 是导入到了错误 namespace：

* 正确导入命令必须含：`ctr -n k8s.io images import ...`

---

## 6) 测试

55.192.0.225 换成服务器对应内网或者外网IP，视服务器环境而定

```http
curl --location 'http://55.192.0.225:31800/v1/chat/completions' \

--header 'Content-Type: application/json' \

--data '{

  "model": "/root/models/Qwen3-0.6B",

  "messages": [

    { "role": "system", "content": "You are a helpful assistant." },

    { "role": "user", "content": "写一篇1000字的作文，关于孙悟空为什么要拜唐僧为师 /no_think" }

  ],

  "temperature": 0.7,

  "max_tokens": 2048

}'
```

![](C:\Users\WL106242\AppData\Roaming\marktext\images\2026-01-15-10-59-17-image.png)
