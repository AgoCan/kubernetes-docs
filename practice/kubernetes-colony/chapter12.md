# 部署多apiserver

**如果想使用多master，请先执行此步骤**    

**如果使用此步骤，自签证书需要加上虚拟ip**

内核支持绑定不存在的ip地址，即可使用 `apiserver` 直接绑定虚拟ip地址.

既，可直接`apiserver` 直接做高可用， 无需使用 `ha` 软件



## keeplived

下载 `keeplived`
```bash
yum install -y keepalived
```
配置文件 `/etc/keepalived/keepalived.conf`

配置文件修改虚拟ip即可，虚拟ip应该跟局域网相同， **每一个节点的priority应该不一样，尽量数字差别大点**

```bash
vrrp_instance VI_1 {
    # 指定 keepalived 的角色，MASTER 表示此主机是主服务器，BACKUP 表示此主机是备用服务器
    state MASTER

    # 指定网卡
    interface ens33

    # 虚拟路由标识，这个标识是一个数字，同一个vrrp实例使用唯一的标识。
    # 即同一vrrp_instance下，MASTER和BACKUP必须是一致的
    virtual_router_id 51

    # 定义优先级，数字越大，优先级越高（0-255）。
    # 在同一个vrrp_instance下，MASTER 的优先级必须大于 BACKUP 的优先级
    priority 100

    # 设定 MASTER 与 BACKUP 负载均衡器之间同步检查的时间间隔，单位是秒
    advert_int 1

    # 设置验证类型和密码
    authentication {
        #设置验证类型，主要有PASS和AH两种
        auth_type PASS
        #设置验证密码，在同一个vrrp_instance下，MASTER与BACKUP必须使用相同的密码才能正常通信
        auth_pass 1111
    }

    #设置虚拟IP地址，可以设置多个虚拟IP地址，每行一个
    virtual_ipaddress {
        # 虚拟 IP
        10.10.10.61
      }
}
```

启动服务
```bash
systemctl start keepalived
systemctl enable keepalived
```

## 部署负载均衡

### 部署nginx

### 部署lvs

### 部署haproxy
