# harbor高可用集群
使用docker-compose进行部署
## 部署keeplived

```bash
yum install -y keepalived
```

配置文件修改

**master:** `/etc/keepalived/keepalived.conf`

```
**[terminal]
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

# 虚拟服务器端口配置
virtual_server 10.10.10.61 80 {
    delay_loop 6
    lb_algo rr
    lb_kind NAT
    persistence_timeout 50
    protocol TCP

    real_server 10.10.10.51 80 {
        weight 1
    }
}
```

back服务器配置：基本与master一直，主要改动部分

**back:** `/etc/keepalived/keepalived.conf`  
其中定义角色可以认为是一个名称而已，主要配置文件是 `priority` 谁数值高，就使用谁的

```
**[terminal]
vrrp_instance VI_1 {
    # 指定 keepalived 的角色，MASTER 表示此主机是主服务器，BACKUP 表示此主机是备用服务器
    state backup

    # 指定网卡
    interface ens33

    # 虚拟路由标识，这个标识是一个数字，同一个vrrp实例使用唯一的标识。
    # 即同一vrrp_instance下，MASTER和BACKUP必须是一致的
    virtual_router_id 51

    # 定义优先级，数字越大，优先级越高（0-255）。
    # 在同一个vrrp_instance下，MASTER 的优先级必须大于 BACKUP 的优先级
    priority 50

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

# 虚拟服务器端口配置
virtual_server 10.10.10.61 80 {
    delay_loop 6
    lb_algo rr
    lb_kind NAT
    persistence_timeout 50
    protocol TCP

    real_server 10.10.10.52 80 {
        weight 1
    }
}
```

启动服务
```bash
systemctl start keepalived
```


## 配置同步机制

两台都部署好harbor之后，配置页面的仓库管理和同步管理，即可做做成主从。 并且配置成定时任务即可
