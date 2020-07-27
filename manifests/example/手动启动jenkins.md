```bash
docker run -itd --runtime=nvidia -e NVIDIA_VISIBLE_DEVICES=all -p 8080:8080 --restart always  -v /data/data01/ev_jenkins/:/var/jenkins_home -v /usr/bin/docker:/usr/bin/docker -v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/nvidia-docker:/usr/bin/nvidia-docker hank997/jenkins:2019.10.24
```

