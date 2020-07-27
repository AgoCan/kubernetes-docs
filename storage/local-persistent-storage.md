# 注意
`hostpath`一旦pvc指定了亲和性节点名称，那么`pod`的使用也需要指定到那一台机器上面
```yaml
nodeAffinity:
  required:
    nodeSelectorTerms:
    - matchExpressions:
      - key: kubernetes.io/hostname
        operator: In
        values:
        - 10.10.10.5
```

挂载文件，首先先在宿主机创建好文件，然后进行创建。

`hostpath`和`nfs`的`capacity`无法限制`pv`大小。  
