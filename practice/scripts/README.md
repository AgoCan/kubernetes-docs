# 脚本

## patch

```bash
#!/bin/sh

for i in `kubectl get deploy -n test-namespace|awk '{print $1}' `
do
# 获取指定字段名称
nodename=`kubectl -n test-namespace get deploy $i -o jsonpath={.spec.template.spec.nodeName}`
if [[ "${nodename}" == "10.10.10.5" ]]
then
# 删掉不想要的字段
#kubectl patch deploy -n test-namespace $i --type='json' -p '[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'
# 替换指定的字段
#kubectl patch deploy -n test-namespace  $i -p '{"spec": {"template": {"spec": {"nodeName": "10.10.10.6"}}}}'

echo $i $nodename
fi
done
```
