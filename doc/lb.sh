# 虚拟IP地址
VIP="55.192.0.1"
# 网卡名
interface="ens0"
# 主备节点，主节点：MASTER，备节点：BACKUP
state="MASTER"
## master节点数组  hostname#ip
masters=("master1#55.192.0.125" "master2#55.192.0.7" "master3#55.192.0.159")


if [ $state = "MASTER" ]; then
    priority=101
else
    priority=100
fi


## 安装keepalived haproxy
#rpm -ivh /data/k8s/yum-repo/yum/lb/*.rpm
# 备份原有配置文件
mv /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.bak
# 创建新的配置文件
cat <<EOF > /etc/keepalived/keepalived.conf
! Configuration File for keepalived
global_defs {
    router_id LVS_DEVEL
}
vrrp_script check_apiserver {
  script "/etc/keepalived/check_apiserver.sh"
  interval 3
  weight -2
  fall 10
  rise 2
}

vrrp_instance VI_1 {
    # 状态，主节点为MASTER，从节点为BACKUP
    state $state
    # 修改为你自己网卡的名字
    interface $interface
    virtual_router_id 51
    # MASTER当中使用101，BACKUP当中使用100
    priority $priority
    authentication {
        auth_type PASS
        # 设置好你的密码，keepalived集群当中需要保证这个值的一致
        auth_pass k8s
    }
    virtual_ipaddress {
        # 注意这里修改为你自己的虚拟IP地址
        $VIP
    }
    track_script {
        check_apiserver
    }
}
EOF

# 编写探活脚本
cat <<EOF > /etc/keepalived/check_apiserver.sh
#!/bin/sh

errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

curl --silent --max-time 2 --insecure https://localhost:6553/ -o /dev/null || errorExit "Error GET https://localhost:6553/"
if ip addr | grep -q $VIP; then
    curl --silent --max-time 2 --insecure https://$VIP:6553/ -o /dev/null || errorExit "Error GET https://$VIP:6553/"
fi
EOF

# 授权
chmod +x /etc/keepalived/check_apiserver.sh

# 备份haproxy的配置文件
mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak

result=""
for item in "${masters[@]}"; do
    name=${item%%#*}
    ip=${item##*#}
    result+="        server $name $ip:6443 check\n"
done
# 把拼接好的字符串赋值给变量
servers=$(echo -e "$result")

# 创建新的配置文件
cat <<EOF > /etc/haproxy/haproxy.cfg

#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    log /dev/log local0
    log /dev/log local1 notice
    daemon

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 1
    timeout http-request    10s
    timeout queue           20s
    timeout connect         5s
    timeout client          20s
    timeout server          20s
    timeout http-keep-alive 10s
    timeout check           10s

#---------------------------------------------------------------------
# apiserver frontend which proxys to the control plane nodes
#---------------------------------------------------------------------
frontend apiserver
    # 注意负载均衡的端口要与keepalived里面的配置保持一致
    bind *:6553
    mode tcp
    option tcplog
    default_backend apiserver

#---------------------------------------------------------------------
# round robin balancing for apiserver
#---------------------------------------------------------------------
backend apiserver
    option httpchk GET /healthz
    http-check expect status 200
    mode tcp
    option ssl-hello-chk
    balance     roundrobin
        # k8s多个主节点直接拼接到后面即可
$servers
EOF


# 启动keepalived和haproxy
systemctl enable --now keepalived
systemctl enable --now haproxy
systemctl restart keepalived.service
systemctl restart haproxy