# Kubernetes API
*把版本号换成自己用的版本号即可*
https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.17/   

## api接口调用认证方式

- **secret token**

- **ca证书** 推荐方式

- **bacis-auth用户名密码方式** 该方式已经逐步移除， 如有必要，需要在`apiserver`的配置文件加上`--bacis-auth-file`参数，详细请查看[创建访问用户](https://kubernetes.hankbook.cn/practice/kubernetes-colony/chapter04.html#%E5%88%9B%E5%BB%BA%E8%AE%BF%E9%97%AE%E7%94%A8%E6%88%B7)

## 使用curl对pod的增删改查

```bash
# 查 GET请求
curl -k --cert /etc/kubernetes/pki/ca.crt --key /etc/kubernetes/pki/ca.key https://10.10.10.5:6443/api/v1/namespaces/default/pods
# 增 POST请求

# 删 DELETE请求

# 改PATCH请求
```
