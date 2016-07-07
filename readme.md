## Deploy marathon blue-green

This is a container with all dependencies to perform a bluegreen deployment in marathon using [Kato](https://github.com/h0tbird/kato "Kato") 

# Overview

This container is using different libraries such [DCOS](https://github.com/dcos/dcos-cli "DC/OS Cli") and [MARATHON-LB](https://github.com/mesosphere/marathon-lb "Marathon-lb") to perform a blue-green delpoyment about any size of stack with different components.
This components should have a specific configuration by labels to perform a blue-green deployment using drain mode of HAProxy.

### Features

* **Multiple Components** you can have many components in yout stack
* **Scalability** If you scalled any of your components to a different size than defined in marathon.json, deploy script detect it and change size
* **0 downtime** Healthchecks in deploymeny is performed by container health, not by container exist.
* **Internal Registry** Deploymeny is compatible with private containers in own registry
* **Environment marathon.json configurable** We can define environment variables in marathon.json
* **DC/OS Compatibility**
* **Environment confirable**

### Howto

Your stack should have a folder /Docker with a folder for each image in stack.
Those images must have a Dockerfile to be build and be deployed in mesos.
Is necessary to have a marathon.json inside those folder to setup how each container should work in stack.
Those marathon.json are compatible with Environemnt variables to define dependencies or common arguments.

We have two types of components. the blue-green deployment component that be deployed by Zdd script in marathon-lb and non blue-green components that's be deployed by DCOS.

we should have a config file with required environment variables mounted in *config/env.$ENV*:

```
: ${MARATHON_URL:='http://<url_marathon>:8080'}
: ${MARATHON_LB_URL:='http://<url_marathon_lb>:9090'}
: ${DOCKER_REGISTRY_EMAIL:='<email_docker_registry_projects>'}
: ${DOCKER_REGISTRY_USER:='<user_docker_registry_projects>'}
: ${DOCKER_REGISTRY_PASS:='<pass_docker_registry_projects>'}
: ${DOCKER_REGISTRY:='internal-registry-sys.marathon:5000'}
: ${PROJECT_NAME:='<project_name>'}
: ${PROJECT_GROUP:='<project_group>'}
: ${PROJECT_VERSION:=''}
PROJECT_COMPONENTS=( <component1> <component2> <component3> )
: ${CID:=$DOCKER_REGISTRY_USER/$PROJECT_NAME}
: ${LATEST:='<boolean>'}
: ${TEMP_FOLDER:="tmp"}
: ${BLUE_GREEN_CONTAINER:="<component_blue-green>"}

```

Example of Non Blue-green php-fpm marathon.json

```
{
  "id": "php-fpm",
  "instances": 1,
  "cpus": 0.2,
  "mem": 256,
  "disk": 0,
  "requirePorts": true,
  "backoffSeconds": 1,
  "backoffFactor": 1.15,
  "maxLaunchDelaySeconds": 3600,
  "labels": {
    "HAPROXY_GROUP": "${PROJECT_GROUP}_${PROJECT_NAME}_php-fpm_${PROJECT_VERSION}",
    "stack_environment": "${PROJECT_GROUP}/${PROJECT_NAME}/${ENV}",
    "stack_version": "${PROJECT_GROUP}/${PROJECT_NAME}/${PROJECT_VERSION}"
  },
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${DOCKER_REGISTRY}/${PROJECT_GROUP}_${PROJECT_NAME}/php-fpm:${PROJECT_VERSION}",
      "network": "BRIDGE",
      "portMappings": [
        { "containerPort": 9000, "hostPort": 0, "servicePort": 10010 }
      ],
      "privileged": false,
      "forcePullImage": false,
      "parameters": [
        { "key": "env", "value": "CONNECTOR=marathon-lb-php"},
        { "key": "log-driver", "value": "gelf" },
        { "key": "log-opt", "value": "gelf-address=udp://logstash-elk-sys.marathon:12201" },
        { "key": "log-opt", "value": "tag=${PROJECT_GROUP}-${PROJECT_NAME}-${PROJECT_VERSION}-php-fpm" }
      ]
    }
  },
  "healthChecks": [
    {
      "portIndex": 0,
      "protocol": "TCP",
      "gracePeriodSeconds": 300,
      "intervalSeconds": 60,
      "timeoutSeconds": 20,
      "maxConsecutiveFailures": 0
    }
  ],
  "upgradeStrategy": {
    "minimumHealthCapacity": 0,
    "maximumOverCapacity": 1
  }
}
```

Example of Non Blue-green haproxy-php marathon.json

```
{
  "id": "marathon-lb-php",
  "cmd": "/marathon-lb/run sse --marathon http://marathon:8080 --health-check --group ${PROJECT_GROUP}_${PROJECT_NAME}_php-fpm_${PROJECT_VERSION}",
  "instances": 1,
  "cpus": 0.1,
  "mem": 64,
  "disk": 0,
  "requirePorts": true,
  "backoffSeconds": 1,
  "backoffFactor": 1.15,
  "maxLaunchDelaySeconds": 3600,
  "dependencies": [
    "/${PROJECT_GROUP}/${PROJECT_NAME}/${PROJECT_VERSION}/php-fpm"
  ],
  "labels": {
    "owner": "api",
    "note": "Api user nginx",
    "stack_environment": "${PROJECT_GROUP}/${PROJECT_NAME}/${ENV}",
    "stack_version": "${PROJECT_GROUP}/${PROJECT_NAME}/${PROJECT_VERSION}",
    "HAPROXY_0_BACKEND_HTTP_OPTIONS": "http-response add-header X-Via %[env\(HOSTNAME\)]"
  },
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${DOCKER_REGISTRY}/${PROJECT_GROUP}_${PROJECT_NAME}/marathon-lb-php:${PROJECT_VERSION}",
      "network": "BRIDGE",
      "portMappings": [
        { "hostPort": 0, "containerPort": 9090 }
      ],
      "privileged": true,
      "parameters": [
        { "key": "log-driver", "value": "gelf" },
        { "key": "log-opt", "value": "gelf-address=udp://logstash-elk-sys.marathon:12201" },
        { "key": "log-opt", "value": "tag=${PROJECT_GROUP}-${PROJECT_NAME}-${PROJECT_VERSION}-marathon-lb-php" }
      ],
      "forcePullImage": false
    }
  },
  "healthChecks": [
    {
      "portIndex": 0,
      "protocol": "TCP",
      "gracePeriodSeconds": 300,
      "intervalSeconds": 60,
      "timeoutSeconds": 20,
      "maxConsecutiveFailures": 0
    }
  ],
  "upgradeStrategy": {
    "minimumHealthCapacity": 0,
    "maximumOverCapacity": 1
  }
}
```

Example of Blue-green marathon.json

```
{
  "id": "nginx",
  "instances": 1,
  "cpus": 0.2,
  "mem": 256,
  "disk": 0,
  "requirePorts": false,
  "backoffSeconds": 1,
  "backoffFactor": 1.15,
  "maxLaunchDelaySeconds": 3600,
  "dependencies": [
    "/${PROJECT_GROUP}/${PROJECT_NAME}/${PROJECT_VERSION}/marathon-lb-php"
  ],
  "labels": {
    "owner": "api",
    "HAPROXY_GROUP": "external",
    "HAPROXY_0_VHOST": "v1.users.sftapi.com",
    "HAPROXY_DEPLOYMENT_GROUP": "${PROJECT_GROUP}_${PROJECT_NAME}_${ENV}",
    "HAPROXY_DEPLOYMENT_ALT_PORT":"10051",
    "stack_environment": "${PROJECT_GROUP}/${PROJECT_NAME}/${ENV}",
    "stack_version": "${PROJECT_GROUP}/${PROJECT_NAME}/${PROJECT_VERSION}"
  },
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "${DOCKER_REGISTRY}/${PROJECT_GROUP}_${PROJECT_NAME}/nginx:${PROJECT_VERSION}",
      "network": "BRIDGE",
      "portMappings": [
        { "containerPort": 80, "hostPort": 0, "servicePort": 80 }
      ],
      "privileged": false,
      "forcePullImage": false,
      "parameters": [
        { "key": "env", "value": "CONNECTOR=marathon-lb-php.user.api" },
        { "key": "env", "value": "VERSION=${PROJECT_VERSION}" },
        { "key": "log-driver", "value": "gelf" },
        { "key": "log-opt", "value": "gelf-address=udp://logstash-elk-sys.marathon:12201" },
        { "key": "log-opt", "value": "tag=${PROJECT_GROUP}-${PROJECT_NAME}-${PROJECT_VERSION}-nginx" }
      ]
    }
  },
  "healthChecks": [
    {
      "gracePeriodSeconds": 120,
      "intervalSeconds": 30,
      "maxConsecutiveFailures": 3,
      "path": "/",
      "portIndex": 0,
      "protocol": "HTTP",
      "timeoutSeconds": 5
    }
  ],
  "upgradeStrategy": {
    "minimumHealthCapacity": 0,
    "maximumOverCapacity": 1
  }
}

```
