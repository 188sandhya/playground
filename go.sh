#!/usr/bin/env bash
set -eo pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
K8S_DIR=$SOURCE_DIR/ci/deployment/k8s
BUILD_MODE="build"
BLITZ_MODE=""
if [[ $* == *--blitz ]]; then
  BUILD_MODE="build-skip-tests"
  BLITZ_MODE="--blitz"
fi

if [[ $* == *--debug ]]; then
  BUILD_MODE="build-debug"
fi

function main {
  case "${1:-}" in

  setup) setup;;
  build-single) buildSingle "${2}";;
  build) buildAll;;
  deploy-local) deployLocal;;
  deploy-local-eb) deployLocalEb;;
  deploy-local-single) deployLocalSingle "${2}";;
  ci) ci;;
  *)
    help
    exit 1
    ;;
  esac
}

function help {
  echo "Usage:"
  echo " build                                      build all containers"
  echo "                                              add --blitz to skip linter and unit tests"
  echo "                                              add --debug to build special for debugging"
  echo " deploy-local                               build all containers and deploy them on minikibe"
  echo "                                              add --blitz to skip linter and unit tests"
  echo "                                              add --debug to build special for debugging"
  echo " deploy-local-eb                           works like deploy-local, but additionally deploys stratford and susie"
  echo " build-single [project directory]           build single container"
  echo "                                              add --blitz to skip linter and unit tests"
  echo "                                              add --debug to build special for debugging"
  echo " deploy-local-single [project directory]    build containers and deploy on minikibe"
  echo "                                              add --blitz to skip linter and unit tests"
  echo "                                              add --debug to build special for debugging"
  echo
  echo " ---------------------------------- EVERYTHING ELSE ----------------------------------"
  echo " setup                                      manually download dependencies, should run when new dependencies are added"
  echo " ci                                         equivalent to running build"
  echo
}

function initDockerEnv {
  if [ -n "${DOCKER_HOST}" ]
  then
    echo "DOCKER_HOST already set"
  else
    eval $(minikube docker-env --shell bash)
    if [ -n "${DOCKER_CERT_PATH}" ] && [ "${DOCKER_CERT_PATH:0:1}" != '/' ]
    then
      DOCKER_CERT_PATH=$(wslpath -u "${DOCKER_CERT_PATH}")
    fi
  fi
}

function buildAll {
  echoGreenText 'Building containers...'
  initDockerEnv
  minikube ssh "sudo cp -f /dev/null /tmp/metro/filebeat/traefik/access.log || sleep 0"
  buildSingle grafana-eb
  docker build -t eb2/eb-createdb metro/init-grafana/create-db/.
  docker build -t eb2/kibana metro/kibana/.
  docker build -t eb2/elastic metro/elastic/.
 
  ./ci/create-configs.sh minikube
  echoBlueText '... finished.'
}

function buildSingle {
  initDockerEnv
  local DIR=$1
  make -C $DIR $BUILD_MODE
}

function deployLocal {
  echoGreenText 'Removing deployments...'
  kubectl delete namespace/squash-debugger || sleep 0
  kubectl delete --namespace=minikube -f ${K8S_DIR}/minikube/namespace.yml || sleep 0
  buildAll $BUILD_MODE
  echoGreenText 'Setup deployments...'
  kubectl create -f ${K8S_DIR}/minikube/namespace.yml
  kubectl create --namespace=minikube -f ${K8S_DIR}/minikube/postgres-dep.yml && sleep 5
  kubectl create --namespace=minikube -f ${K8S_DIR}/minikube/oma-high-priority.yml \
    && kubectl create --namespace=minikube -f ${K8S_DIR}/minikube/oma-medium-priority.yml \
    && kubectl create --namespace=minikube -f ${K8S_DIR}/minikube/oma-susie-high-priority.yml \
    && kubectl create --namespace=minikube -f ${K8S_DIR}/minikube/oma-susie-medium-priority.yml \
    && kubectl create --namespace=minikube -f ${K8S_DIR}/minikube/oma-susie-low-priority.yml

  kubectl create --namespace=minikube -f ${K8S_DIR}/minikube/ || sleep 1

  kustomize build --enable-alpha-plugins waas-config/environments/local | kubectl apply --namespace=minikube -f - 
  sleep 5
  echoBlueText '... finished.'

  echoGreenText 'Setup grafana-controller...'
  (cd ../errorbudget-grafana-controller; ./go.sh deploy-local $BLITZ_MODE)
  kubectl config set-context --current --namespace=minikube
  echoGreenText '... finished.'
}

function deployLocalEb {  
  deployLocal $BUILD_MODE

  echoGreenText 'Setup test config...'
  cd ../errorbudget-prometheus-playground/
  ./deploy.sh insertMetrics

  echoGreenText 'Setup susie...'
  cd ../errorbudget-susie/
  ./go.sh deploy-local $BLITZ_MODE

  echoGreenText 'Setup sda...'
  cd ../errorbudget-sda/
  ./go.sh deploy-local

  echoGreenText 'Setup sda-sidecar...'
  cd ../errorbudget-sda-sidecar/
  ./go.sh deploy-local $BLITZ_MODE

  echoBlueText '... finished.'
}

function deployLocalSingle {
  local DIR=$1
  echoGreenText 'Removing deployment...'
  if [ "$DIR" == "grafana-eb" ]; then DIR="grafana"; fi
  kubectl delete -f "${K8S_DIR}/$DIR-dep.yml" || sleep 0
  buildSingle $1
  echoGreenText 'Setup deployment...'
  kubectl create -f "${K8S_DIR}/$DIR-dep.yml"
  echoBlueText '... finished.'
}

function deployLocalSkipTests {
  deployLocal "build-skip-tests"
}

function ci {
  make -C grafana-eb build
  docker build -t eb2/eb-createdb metro/init-grafana/create-db/.
}

function setup {
  echoGreenText 'Setup...'
  minikube cache add alpine:3.11
  # pulling from private registry isn't working with credentials
  # minikube cache add registry.metroscales.io/errorbudget/golang-extras:1.14
  minikube cache add burakince/drakov:1.2.1
  minikube cache add burakince/dredd-with-wait-for-host:1.0.0
  minikube cache add docker.elastic.co/elasticsearch/elasticsearch-oss:7.5.1
  minikube cache add docker.elastic.co/kibana/kibana-oss:7.5.1
  minikube cache add ruby:2.2
  minikube cache add node:12.16.1-alpine3.11
  minikube cache add traefik:v2.4.8
  minikube cache add prom/prometheus:v2.15.2
  minikube cache add postgres:10.6-alpine
  helm repo add traefik https://helm.traefik.io/traefik > /dev/null 2>&1
  helm install -n minikube --create-namespace traefik traefik/traefik --version 9.20.1 > /dev/null 2>&1 || true
}

function echoGreenText {
  if [[ "${TERM:-dumb}" == "dumb" ]]; then
    echo "${@}"
  else
    RESET=$(tput sgr0)
    GREEN=$(tput setaf 2)

    echo "${GREEN}${@}${RESET}"
  fi
}

function echoBlueText {
  if [[ "${TERM:-dumb}" == "dumb" ]]; then
    echo "${@}"
  else
    RESET=$(tput sgr0)
    BLUE=$(tput setaf 4)

    echo "${BLUE}${@}${RESET}"
  fi
}
function echoRedText {
  if [[ "${TERM:-dumb}" == "dumb" ]]; then
    echo "${@}"
  else
    RESET=$(tput sgr0)
    RED=$(tput setaf 1)

    echo "${RED}${@}${RESET}"
  fi
}

function echoWhiteText {
  if [[ "${TERM:-dumb}" == "dumb" ]]; then
     echo "${@}"
  else
    RESET=$(tput sgr0)
    WHITE=$(tput setaf 7)

    echo "${WHITE}${@}${RESET}"
  fi
}

if [[ "${TEST_MODE:-}" = "" ]]; then
  main "$@"
fi
