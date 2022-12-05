#!/bin/bash

DIRECTORY=$1
GRAFANA_PLUGINS_DIR="/var/lib/grafana/plugins"

POD_NAME=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" -l app=grafana -n minikube)

function rmGrafanaDirectory() {
    kubectl exec -i -n minikube "$POD_NAME" -- rm -r "$1"/
}

function buildAndReload() {
    GRAFANA_DESTINATION_DIR=$1
    npm run --prefix ./"$DIRECTORY" build
    echo "built"

    rmGrafanaDirectory "$GRAFANA_DESTINATION_DIR"/
    echo "grafana directory cleaned"

    kubectl cp ./"$DIRECTORY"/dist/ minikube/"$POD_NAME":"$GRAFANA_DESTINATION_DIR"
    echo "code copied"
}

function reloadSavedQueries() {
    kubectl cp ./scripted-datasource/queries/ minikube/"$POD_NAME":"$GRAFANA_PLUGINS_DIR"/scripted-datasource/queries
    echo "queries copied"
}

if [ "${DIRECTORY}" == "plugin/queries" ]; then
    rmGrafanaDirectory "$GRAFANA_PLUGINS_DIR"/scripted-datasource/queries
    reloadSavedQueries
elif [ "${DIRECTORY}" == "plugin" ]; then
    buildAndReload "$GRAFANA_PLUGINS_DIR/eb"
elif [ "${DIRECTORY}" == "echarts" ]; then
    buildAndReload "$GRAFANA_PLUGINS_DIR/echarts"
elif [ "${DIRECTORY}" == "scripted-datasource" ]; then
    buildAndReload "$GRAFANA_PLUGINS_DIR/scripted-datasource"
    reloadSavedQueries
else
    echo Unknown directory: "$DIRECTORY". Possible options: \"echarts\" \& \"plugin\" 
    exit 1
fi


