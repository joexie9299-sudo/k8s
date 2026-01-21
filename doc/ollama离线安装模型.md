## 说明

本文档描述了离线安装ollama模型方式，通过huggingface下载gguf文件（大语言模型权重文件）安装模型

## 资料库

| 名称          | 地址                                              | 介绍                                                                                                                | 
|-------------|-------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| huggingface | https://huggingface.co/                         | Hugging Face 是一个 AI 开发者的生态平台，提供模型、数据集和工具，帮助大家快速构建和分享人工智能应用。                                                       |
| modelfile说明 | https://ollama.readthedocs.io/modelfile/#format | 在 Ollama 里，Modelfile 是一个配置文件，用来定义和构建你自己的模型镜像（类似 Dockerfile 的概念）。它告诉 Ollama 如何基于某个已有模型进行定制，比如添加系统提示、修改参数、或者组合多个模型。 |

### 下载大预言模型权重文件

- 选择合适的权重文件下载至本地：https://huggingface.co/Qwen/Qwen1.5-0.5B-Chat-GGUF/tree/main
- 编写Modelfile文件，文件内容如下

       # 写权重文件的地址   
       FROM ./qwen2.5-0_5b.gguf
- 进入ollama pod内执行以下命令
      
      # 创建模型
      ollama create qwen2.5 -f Modelfile
      # 查看模型列表
      ollama list