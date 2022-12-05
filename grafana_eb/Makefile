.PHONY: build build-skip-tests build-debug

PROJECT=eb-grafana
GRAFANA_SIGNING_KEY=$(shell sops -d ../waas-config/environments/local/application.secrets.yaml | yq r - "GRAFANA_SIGNING_KEY")

build build-skip-tests build-debug:
	docker build -t eb2/$(PROJECT) --build-arg GRAFANA_API_KEY=${GRAFANA_SIGNING_KEY} .

reload-plugin:
	./reload.sh "plugin"
	
reload-echarts:
	./reload.sh "echarts"

reload-ds:
	./reload.sh "scripted-datasource"

reload-queries:
	./reload.sh "plugin/queries"