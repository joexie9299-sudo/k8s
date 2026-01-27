# 安装网络插件 calico
kubectl apply -f /data/k8s/yaml/calico.yaml
## 检查POD是否都正常RUNNING
kubectl get pod -n kube-system
## 检查node状态是否都Ready
kubectl get node

# 安装kubernetes-dashboard
# install
helm install kubernetes-dashboard /data/k8s/heml/kubernetes-dashboard-7.14.0.tgz --create-namespace --namespace kubernetes-dashboard
# 检查POD是否都正常RUNNING
kubectl get pod -n kubernetes-dashboard
# 创建用户
kubectl apply -f /data/k8s/yaml/user-service.yaml
kubectl apply -f /data/k8s/yaml/user.yaml

## 安装 gpu-operator
kubectl create ns gpu-operator
kubectl label --overwrite ns gpu-operator pod-security.kubernetes.io/enforce=privileged
helm install gpu-operator /data/k8s/heml/gpu-operator-v25.10.1.tgz --namespace gpu-operator --set driver.enabled=false
helm upgrade --install gpu-operator /data/k8s/heml/gpu-operator-v25.10.1.tgz \
  -n gpu-operator \
  --set devicePlugin.enabled=false \
  --set driver.enabled=false

## 检查pod是否都正常RUNNING
kubectl get pod -n gpu-operator