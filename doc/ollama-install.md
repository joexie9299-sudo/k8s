## 安装Ollama，并运行大模型（GPU调度），将服务暴露出来供业务开发方使用

安装物料：https://app-center-9a80a0dd892e4a7085270719d64e89c3.obs.ap-southeast-1.myhuaweicloud.com:443/ollama.zip?AccessKeyId=HPUA7USXCYBYESN2UX28&Expires=1799557866&Signature=Qv%2BtvtHTBz18eX2VvUn4pC1H5is%3D

    # （GPU节点）解压ollama.zip
    unzip ollama.zip
    # （GPU节点）解压ollama离线镜像，其它版本可以去docker仓库下载，https://hub.docker.com/r/ollama/ollama
    ctr -n k8s.io images import ollama/ollama.tar
    
    # （master节点）部署
    kubectl apply -f /data/k8s/yaml/ollama.yaml
    
    # （master节点）查看运行状态
    kubectl get pod
    
    # （GPU节点）离线安装模型
    # （GPU节点）创建目录
    mkdir -p /data/openebs/local/ollama
    # （GPU节点）将已经下载好的模型移动至目录内，以便pod可以读取到文件
    mv ollama/qwen1_5-0_5b.gguf /data/openebs/local/ollama
    # （GPU节点）创建Modelfile文件
    cat >> Modelfile <<EOF
    # （GPU节点）写权重文件的地址   
    FROM ./qwen1_5-0_5b.gguf
    EOF
    # （GPU节点）将Modelfile文件与权重文件放置至同一目录下
    mv Modelfile /data/openebs/local/ollama
    
    # （master节点）进入ollama POD内
    kubectl get pod | grep ollama
    kubectl exec -it ollama-6f447c9f67-wxs47  -- /bin/bash
    # (POD容器内)进入挂载的目录
    cd /root/.ollama/
    # (POD容器内)创建模型
    ollama create qwen1.5:0.5b -f Modelfile
    # (POD容器内)查看模型列表
    ollama list
    # (POD容器内)验证是否用到GPU 查看进程
    ollama ps
    
    # （master节点）查看服务端口
    kubectl get service | grep ollama
    
    # 访问，集群任意IP+端口
    curl http://55.192.0.225:31434/

## 资料库

| 名称          | 地址                                              | 介绍                                                                                                                | 
|-------------|-------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| huggingface | https://huggingface.co/                         | Hugging Face 是一个 AI 开发者的生态平台，提供模型、数据集和工具，帮助大家快速构建和分享人工智能应用。                                                       |
| modelfile说明 | https://ollama.readthedocs.io/modelfile/#format | 在 Ollama 里，Modelfile 是一个配置文件，用来定义和构建你自己的模型镜像（类似 Dockerfile 的概念）。它告诉 Ollama 如何基于某个已有模型进行定制，比如添加系统提示、修改参数、或者组合多个模型。 |

### 下载大语言模型权重文件

- 选择合适的权重文件下载至本地：https://huggingface.co/Qwen/Qwen1.5-0.5B-Chat-GGUF/tree/main
- 编写Modelfile文件，文件内容如下

       # 写权重文件的地址   
       FROM ./qwen2.5-0_5b.gguf
- 进入ollama pod内执行以下命令

      # 创建模型
      ollama create qwen2.5 -f Modelfile
      # 查看模型列表
      ollama list