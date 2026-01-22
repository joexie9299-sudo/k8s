# 物料准备

- 下载：https://app-center-9a80a0dd892e4a7085270719d64e89c3.obs.ap-southeast-1.myhuaweicloud.com:443/vllm/vllm-vllm-openai_latest.tar.gz?AccessKeyId=HPUA7USXCYBYESN2UX28&Expires=1800149565&Signature=yfMhSaE19l9FUDTif7jBFORpClc%3D

- 说明：链接内下载的包内包含了部署vLLM用到的**容器镜像**、演示部署用到的**大模型**，后续实际使用到的**大模型**需要按需去HF或其他仓库内下载

  - https://huggingface.co/

  - ~~~
    ## 选择模型后，clone至本地
    git clone https://huggingface.co/Qwen/Qwen3-0.6B
    ## 打包
    tar -czvf Qwen3-0.6B_hf.tar.gz Qwen3-0.6B
    ## 上传至离线环境，解压缩后即可被vllm读取使用
    tar -xzvf Qwen3-0.6B_hf.tar.gz -C /data/vllm/models
    ~~~

- 解压后的目录说明

  - ~~~
    vllm
    ├── Qwen3-0.6B_hf.tar.gz 大模型文件，此处演示部署，使用0.6B的模型
    └── vllm-vllm-openai_latest.tar.gz vLLM的镜像文件
    ~~~

- 该文件包，需要上传至所有**GPU Woker Node Server**内

# 部署安装vLLM

- GPU Woker Node Server执行

  - ~~~
    # 将上一步骤下载的包上传至**GPU Woker Node Server**解压缩
    tar xvf vllm-package.tar.gz
    
    # 进入目录
    cd vllm
    
    # 导入镜像（镜像文件较大，需要等待一段时间）
    gunzip -c vllm-vllm-openai_latest.tar.gz | sudo ctr -n k8s.io images import -
    
    # 确认镜像导入成功
    ctr -n k8s.io images ls -q | grep vllm
    
    # 将大模型文件解压缩，存放至固定目录下(请记住这个目录，后续会使用到)，这里使用 /data/vllm/models
    mkdir -p /data/vllm/models
    tar -xzvf Qwen3-0.6B_hf.tar.gz -C /data/vllm/models
    ~~~

- Master Node Server执行

  - 修改vLLM YAML文件

    - metadata.name：请按照实际的name命名，方便管理，例如QWen3.0:0.6B的模型，可以命名为“vllm-qwen3-0p6b”

      - 请将所有“vllm-qwen3-0p6b”涉及到的值都一并修改

    - resources.limit：给POD分配的资源限制

      - nvidia.com/gpu: "1" 表示给POD分配了1个GPU（这个数字不能大于物理GPU的个数）
      - nvidia.com/gpumem: 5000 表示给POD分配了5000M显存（这个数字不能大于单个GPU的最大显存）
      - nvidia.com/gpucores: 30 表示给POD分配了30%的GPU核心

    - volumes：**models-vol**是vllm容器内模型目录挂载到宿主机的磁盘目录，这里我们要写成上一步骤，我们存放模型文件的目录**/data/vllm/models**

    - namespace：可以指定该实例的namespace，在安装K8S集群时，我们创建了不同测试环境的namespace，如若需要区分环境部署vllm，那么可以指定到不同的namespace内

    - spec.ports.nodePort：暴露的端口，按实际调整，不要发生冲突

    - ~~~
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
            runtimeClassName: nvidia
      
            volumes:
              - name: models-vol
                hostPath:
                  path: /data/vllm/models
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
                  limits:
                    nvidia.com/gpu: "1" # declare how many physical GPUs the pod needs
                    nvidia.com/gpumem: 5000 # identifies 5000M GPU memory each physical GPU allocates to the pod （Optional,Integer）
                    nvidia.com/gpucores: 30 # identifies 30% GPU GPU core each physical GPU allocates to the pod （Optional,Integer)
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
      ~~~

    - 本次用到的YAML文件下载地址：https://app-center-9a80a0dd892e4a7085270719d64e89c3.obs.ap-southeast-1.myhuaweicloud.com:443/vllm/vllm-qwen3b0p6.yaml?AccessKeyId=HPUA7USXCYBYESN2UX28&Expires=1800153723&Signature=kAZGQbXRKnqSCfKoOthNFEdNSDo%3D

  - ~~~
    ## Master 执行yaml文件
    kubectl apply -f vllm-qwen3b0p6.yaml
    
    ## 查看pod状态(启动需要一定时间，请等待)
    kubectl get pod -A | grep vllm
    
    ## 可以查看容器日志(直到RUNNING状态1/1即可)
    kubectl logs <pod-name> -n <namespace-name>
    
    ## 启动完成后测试
    curl --location 'http://55.192.0.125:31800/v1/chat/completions' \
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
    ~~~







