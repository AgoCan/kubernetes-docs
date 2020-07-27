# 备份
## 方案1：获取所有镜像

使用下面的脚本，获取所有的镜像名称，然后 使用 `docker pull` 方式备份，harbor版本是1.7之后

```python
import  requests
import json

url="https://10.10.10.51"
image_url="10.10.10.5"
login_url="/c/login"
project_url="/api/projects?page=1&page_size=3000"
repo_url="/api/repositories?page=1&page_size={size}&project_id={id}"
image_url="/api/repositories/{image}/tags?detail=1"
tag_url="/api/repositories/admin001/test123/tags?detail=1"
login_arg={"principal":"admin","password":"Harbor12345"}

r=requests.post(url+login_url,data=login_arg,verify=False)
cookies=r.cookies
a=requests.get(url+project_url,cookies=cookies,verify=False)
for i in json.loads(a.text):
    if int(i['repo_count']) > 0:
        b=requests.get(url+repo_url.format(size=i['repo_count']+1,id=i['project_id']),cookies=cookies,verify=False)
        for repo in json.loads(b.text):
            c=requests.get(url+image_url.format(image=repo['name']),cookies=cookies,verify=False)
            for tag in json.loads(c.text):
                print(image_url+repo['name']+":"+tag['name'])
```

## 方案2： 搭建双主的harbor仓库
