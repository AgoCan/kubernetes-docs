创建`pipeline`的格式，然后复制下面的`scripts`既可使用上线，如需了解更多，请上官方进行查看各个组件的使用


上线模版
```
def label = "worker-${UUID.randomUUID().toString()}"

podTemplate(label: label, containers: [
  containerTemplate(name: 'docker', image: 'docker', command: 'cat', ttyEnabled: true),
  containerTemplate(name: 'maven', image: 'maven:3.3.9-jdk-8-alpine', ttyEnabled: true, command: 'cat')
],
volumes: [
  hostPathVolume(mountPath: '/var/run/docker.sock', hostPath: '/var/run/docker.sock')，

]) {
  node(label) {
    stage('Get a Maven Project') {
        git branch: 'master',credentialsId: 'xxxx',url: 'https://xxxxxx.git'
        container('maven') {
                stage('Build a Maven project') {
                    sh 'mvn -B clean install -DskipTests=true'
                }
            }
    }
    stage('Create Docker images') {
      container('docker') {
          sh """
            docker login -u admin -p Harbor12345
            docker built -t image:v1 .
            docker push image:v1

            """

      }
    }
  }
}
```

其中`docker`镜像里面包含了`docker`命令,下面这个挂载是可以不使用的
```
hostPathVolume(mountPath: '/opt/kube/bin/docker', hostPath: '/usr/bin/docker'),
```
