#!/usr/bin/env bash
set -eo pipefail

SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR=$SOURCE_DIR/..


function main {
  rm ${SOURCE_DIR}/deployment/k8s/metro/grafana-dep.yml  &> /dev/null || true
  rm ${SOURCE_DIR}/deployment/k8s/metro/elastic-cleaner-cj.yml  &> /dev/null || true
  case "${1:-}" in

  minikube) minikube "${@:2}";;
  metro) metro "${@:2}";;
  *)
    help
    exit 1
    ;;

  esac
}

function help {
  echo "Usage:"
  echo " minikube                                generate config maps for local development"
  echo " metro {namespace} {image_tag} {stage}   generate config maps for metro infrastructure"
  echo "                                           default {namespace} : errorbudget-pp"
  echo "                                           default {image_tag} : latest"
  echo "                                           default {stage}     : pp (options: pp or prod)"
  echo
}


function minikube {
    DOCKER_REGISTRY="eb2"
    METRO_NAMESPACE="minikube"

    kubectl create configmap traefik-config -n kube-system --from-file=${PROJECT_DIR}/metro/traefik -n $METRO_NAMESPACE -o yaml --dry-run  > ${SOURCE_DIR}/deployment/k8s/minikube/traefik-cfg.yml

    generate_helm "${DOCKER_REGISTRY}/eb-grafana,createdbimage=${DOCKER_REGISTRY}/eb-createdb" $METRO_NAMESPACE grafana-chart ${SOURCE_DIR}/deployment/k8s/grafana-dep.yml
    generate_helm "" $METRO_NAMESPACE elastic-cleaner-chart ${SOURCE_DIR}/deployment/k8s/elastic-cleaner-cj.yml

    echo "Kubernetes yamls created"
}

function metro {
    METRO_NAMESPACE="errorbudget-pp"
    TAG="latest"
    STAGE="pp"
    DOCKER_REGISTRY="registry.metroscales.io/errorbudget"
    if [ "$#" -eq 3 ]; then
        METRO_NAMESPACE=$1
        TAG=$2
        STAGE=$3
    fi

    if [ "${STAGE}" == "pp" ]; then
      CLUSTER_HOST="api-mcdr-001-test3-msys-be-gcw1.metroscales.io"
      HOSTNAME="oma-pp.metro.digital"
    elif [ "${STAGE}" == "prod" ]; then
      CLUSTER_HOST="api-mcdr-001-live3-msys-be-gcw1.metroscales.io"
      HOSTNAME="oma.metro.digital"
    else
      help
      exit 1
    fi
    echo "Using namespace: $METRO_NAMESPACE, TAG: $TAG, STAGE: $STAGE"

    generate_helm "${DOCKER_REGISTRY}/eb-grafana:${TAG},createdbimage=${DOCKER_REGISTRY}/createdb:${TAG},cluster=${CLUSTER_HOST},hostname=${HOSTNAME},serviceversion='${TAG}',stage=${STAGE}" $METRO_NAMESPACE grafana-chart ${SOURCE_DIR}/deployment/k8s/metro/grafana-dep.yml
    generate_helm ",stage=${STAGE},serviceversion='${TAG}'" $METRO_NAMESPACE elastic-cleaner-chart ${SOURCE_DIR}/deployment/k8s/metro/elastic-cleaner-cj.yml

    echo "Kubernetes yamls created"
}

function generate_helm {
    echo "$3"
    helm_template image=$1,namespace=$2 $3 $4
}

function helm_template() {
    file_path=${3:?}
    helm lint --set $1 --strict ${SOURCE_DIR}/deployment/$2
    helm template --set $1 ${SOURCE_DIR}/deployment/$2 > "$file_path"
}

main "$@"