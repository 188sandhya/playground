# Minikube
Minikube virtual machine must be **created** with more memory than default. Ie.: `minikube start --cpus 4 --memory 8192`

Also for ELK to start some additional changes are required:

`minikube start --cpus 4 --memory 8192 --disk-size=60GB`

`minikube ssh 'echo "sysctl -w vm.max_map_count=262144" | sudo tee -a /var/lib/boot2docker/bootlocal.sh'`

`minikube stop`

`minikube start`

# Traefik
Before deploying the project, Traefik v2 has to be installed. The steps are:
- be sure that you have helm version > 3.2
- add repo: `helm repo add traefik https://helm.traefik.io/traefik`
- install traefik: `helm install -n minikube --create-namespace traefik traefik/traefik --version 9.20.1`

All images has to be build and start them on minikube docker:

`./go.sh deploy-local`

## Usage of _go.sh_
All possible commands with short description to use _go.sh_:
```
 build                                      build all containers
                                              add --blitz to skip linter and unit tests
 deploy-local                               build all containers and deploy them on minikibe
                                              add --blitz to skip linter and unit tests
 build-single [project directory]           build single container
                                              add --blitz to skip linter and unit tests
 deploy-local-single [project directory]    build containers and deploy on minikibe
                                              add --blitz to skip linter and unit tests
 cdc                                        runs the cdc test once
 cdc-preserve                               runs the cdc test once and leaves containers to dev

 ---------------------------------- EVERYTHING ELSE ----------------------------------
 setup                                      manually download dependencies, should run when new dependencies are added
 ci                                         equivalent to running build, tests and blueprints
```

## Services and ports
If your minikube ip is 192.168.99.100 then:

http://192.168.99.100:30000 - grafana

http://192.168.99.100:30000/kibana - kibana like in metro setup (through traefik)

http://192.168.99.100:30001/dashboard/ - traefik

http://192.168.99.100:30005 - grafana-controller

# Secrets
Secrets & Passwords to set before using:

ci/deployment/k8s/metro/scratch/idamsecret.yml

 - `__IDAM_CLIENT_SECRET__`
   -  base64 encoded secret

ci/deployment/k8s/metro/scratch/dockerregistrykey.yml

 - `__DOCKER_REGISTRY_SECRET__`
   - format: `{"auths":{"registry-mcdr-001-test2-peng-be-gcw1.metroscales.io/pp/errorbudget":{"username":"registry","password":"...","auth":"..."}}}`
   - password - `registry password`
   - auth - `base64 encoded value from: username:password`
   - the entire string has to base64 encoded

ci/deployment/k8s/metro/scratch/postgresurl.yml

 - `__POSTGRES_URL_WITH_BASIC_AUTH__`
   - the entire string has to base64 encoded with DB name added (e.g. /grafana)

ci/deployment/k8s/metro/scratch/analytics-google.yml

 - `__JSON_CREDENTIALS__`
  - base64 encoded json credentials to google analytics
 - `__VIEW_ID__`
  - base64 encoded view id to google analytics
 - `__TRACKING_ID__`
  - base64 encoded tracking id to google analytics

ci/deployment/k8s/metro/scratch/service-discovery-secret.yml

 - `__SERVICE_DISCOVERY_AUTH__`
  - auth - `base64 encoded value from: username:password`

# Deploying on test3-msys

## Deploying first time
Before deploying `ci/deployment/k8s/metro/scratch/` it's needed to prepare secrets with correct data (Look above). Also if you want use diffrent namespace you have to change this before apply yaml to Kubernetes.

Preparation:
  1. Prepare secrets with correct data (Look above)
  2. If you want deploy on diffrent namespace than default (errorbudget-pp), you have to change and check:
     - ingress urls are hardcoded in `ci/create-configs.sh` and change if you need
     - change namespaces if you need
  3. Generate yaml and config maps using `SERVICE_DISCOVERY_USER={service_discovery_user} SERVICE_DISCOVERY_PASSWORD={service_discovery_password} ./ci/create-configs.sh metro {namespace} {image_tag} {stage}` where
     - service_discovery_user should be username used to generate service-discovery-secret secret (decoded base64)
     - service_discovery_user should be password used to generate service-discovery-secret secret (decoded base64)
     - namespace should be e.g. *errorbudget_pp*
     - image_tag should be e.g. *latest* or tag from last success build on Jenkins
     - stage should be e.g. *pp* or *prod* it setup urls and docker registry based on the stage 

Deploying:
  1. From *ci/deployment/k8s/metro/scratch*:
     1. First apply *namespace.yml* 
     2. Apply *pvc.yml* and all secrets
  2. From *k8s/metro* apply
     2. *grafana-dep.yml*, *grafana-controller-dep.yml*

## Redeploy 
  Before redeploy always generate yaml and config maps using `SERVICE_DISCOVERY_USER={service_discovery_user} SERVICE_DISCOVERY_PASSWORD={service_discovery_password} ./ci/create-configs.sh metro {namespace} {image_tag} {stage}`.

___
# Debugging with [Telepresence](https://github.com/telepresenceio/telepresence)

> __Telepresence allows:__
> - your locally running code to access k8s services
> - kubernetes to access your locally running code
### `Locally running apps are available via their original minikube addresses.`
### `Do not access them via 'localhost'`

### Preconditions
- VPN is disconnected

### Install telepresence
```
https://www.telepresence.io/reference/install
```

# Debug
##### While project is running on minikube, to debug:

## grafana-controller:
Set up __launch.json__ file with basic configuration:
```JSON
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Launch",
            "type": "go",
            "request": "launch",
            "mode": "auto",
            "program": "${workspaceFolder}/grafana-controller/main",
            "env": {
                "GRAFANA_USER": "admin",
                "GRAFANA_PASSWORD": "admin",
                "GRAFANA_SECRET": "grafana_secret",
                "RESOURCE_PATH": "${workspaceFolder}/grafana-controller/resource/"
            },
            "args": []
        }
    ]
}
```
Create proxy to host machine with command:
```
telepresence --namespace minikube --swap-deployment grafana-controller --run-shell
```
Following response is expected:
> T: Forwarding remote port 8000 to local port 8000.  
> T: Setup complete. Launching your command.  
> @minikube|bash-3.2$  

At this point, grafana_controller deployment should be replaced with new one (kubectl get pods -n minikube)

Next steps:
- Launch grafana_controller with __launch.json__ from point no.1
- Set up breakpoint
- Debug

## Debug Golang in minikube

#### Prerequest

Install extension to VS Code called `Squash`(https://squash.solo.io/).

#### Debugging

  1. Open workspace in VS Code where is Dockerfile.
  2. Run `./go.sh deploy-local --debug`.
  3. After deploy run `Squash - debug pod` in VS Code (CTRL/CMD + SHIFT + P). Lead steps, choose pod and `dlv` mode. First setting up and connection to pod it might take a while.

# grafana (plugin):
Checkout Grafana source code

Add __custom.ini__ file at /github.com/grafana/grafana/conf/custom.ini
```ini
[paths]
plugins = /workspace/go/errorbudget-prometheus-playground/grafana-eb/plugin

[database]
url = postgres://postgres:example@postgres:5432/grafana

[security]
secret_key = grafana_secret
```

Create proxy to host machine with command:
```
telepresence --namespace minikube --swap-deployment grafana --run-shell
```

Build & Run grafana (https://grafana.com/docs/project/building_from_source)
> yarn start - starts frontend  
> make run - starts backend  

Next steps:
- go to /grafana-eb/plugin
- run command: `npm i`
- run command: `npm run watch`
- make changes to plugin sources & refresh page

# Stop debugging
#### Execute `exit` command in telepresence shell to replace local deployment with original one.
