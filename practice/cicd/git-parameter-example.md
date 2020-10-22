
安装插件 `git-parameter:0.9.13`

```
  installPlugins:
    - kubernetes:1.25.7
    - workflow-job:2.39
    - workflow-aggregator:2.6
    - credentials-binding:1.23
    - git:4.2.2
    - configuration-as-code:1.43
    - localization-zh-cn:1.0.20
    - git-parameter:0.9.13
    - git-tag-message:1.7.1
```

```
def label = "worker-${UUID.randomUUID().toString()}"
parameters {
        gitParameter name: 'TAG',
        type: 'PT_TAG',
        defaultValue: 'master'}
podTemplate(label: label,
            serviceAccount: "jenkins",

            containers: [
                containerTemplate(name: 'docker', image: 'docker', command: 'cat', ttyEnabled: true),
                containerTemplate(name: 'kubectl', image: 'hank997/kubectl:1.15.9', command: 'cat', ttyEnabled: true)
            ],
            volumes: [
  hostPathVolume(mountPath: '/var/run/docker.sock', hostPath: '/var/run/docker.sock')])
{node(label) {
    stage("echo"){
        sh """
            echo ${params.TAG}
        """
    }
    stage("checkout"){
        checkout([$class: 'GitSCM',
                          branches: [[name: "${params.TAG}"]],
                          doGenerateSubmoduleConfigurations: false,
                          extensions: [],
                          gitTool: 'Default',
                          submoduleCfg: [],
                          userRemoteConfigs: [[url: 'https://github.com/AgoCan/go-helloworld.git']]
                        ])
    }
    stage('Create Docker images') {
      container('docker') {
          sh """
            docker login -u admin --password Harbor12345
            docker build -t hank997/hello-go:v2 .
            docker push hank997/hello-go:v2
            """

      }
    }
    stage("kubectl"){
        container('kubectl') {
            sh """
            kubectl set images  pod/test-go-http-pod test-go-http-pod=hank997/hello-go:v2
            """
        }
            //sh "kubectl set images pod/test-go-http-pod test-go-http-pod=hank997/hello-go:v2"
    }
  }
}
```
