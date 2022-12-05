FROM registry.metroscales.io/errorbudget/node:16.7.0-bullseye-slim as builder
RUN apt-get update
RUN apt-get install -y ca-certificates git wget python3 make g++ unzip
RUN apt-get install openssl && apt-get clean

ARG LOCAL_ADRESS=http://192.168.99.100:30000
ARG GRAFANA_API_KEY="grafana_api_key_token"

RUN mkdir /datadog
WORKDIR /datadog
RUN git clone --depth 1 https://github.com/sirkjohannsen/grafana-datasource-datadog.git .
RUN sed -i 's/grafana-datadog-datasource/datadog/g' ./dist/plugin.json

RUN mkdir /piechart-panel
WORKDIR /piechart-panel
RUN wget https://github.com/grafana/piechart-panel/releases/download/v1.5.0/grafana-piechart-panel-1.5.0.zip
RUN unzip grafana-piechart-panel-1.5.0.zip && \
    rm grafana-piechart-panel-1.5.0.zip

RUN mkdir /github-datasource
WORKDIR /github-datasource
RUN wget https://github.com/grafana/github-datasource/releases/download/v1.0.8/grafana-github-datasource-1.0.8.linux_amd64.zip
RUN unzip grafana-github-datasource-1.0.8.linux_amd64.zip && \
    rm grafana-github-datasource-1.0.8.linux_amd64.zip

RUN mkdir /bigquery-datasource
WORKDIR /bigquery-datasource
RUN wget -O bigquery-datasource.zip https://github.com/doitintl/bigquery-grafana/archive/refs/tags/1.0.7.zip
RUN unzip bigquery-datasource.zip && rm bigquery-datasource.zip

# get Metro plugin
RUN mkdir /metro-plugin
WORKDIR /metro-plugin
RUN wget https://dx-nexus.metroscales.io/repository/errorbudget-grafana-plugins/metro-plugin.2.2.13.zip
RUN unzip metro-plugin.2.2.13.zip && \
    rm metro-plugin.2.2.13.zip

# get OMA config
RUN mkdir /oma-config
WORKDIR /oma-config
RUN wget https://dx-nexus.metroscales.io/repository/errorbudget-grafana-plugins/oma-config.2.5.1.zip
RUN unzip oma-config.2.5.1.zip && \
    rm oma-config.2.5.1.zip

# get OMA SDA dashboards
RUN mkdir /oma-sda-dashboards
WORKDIR /oma-sda-dashboards
RUN wget https://dx-nexus.metroscales.io/repository/errorbudget-grafana-plugins/oma-sda-dashboards.1.0.0.zip
RUN unzip oma-sda-dashboards.1.0.0.zip && \
    rm oma-sda-dashboards.1.0.0.zip

# get ScriptedDS plugin
RUN mkdir /scripted-datasource
WORKDIR /scripted-datasource
RUN wget https://dx-nexus.metroscales.io/repository/errorbudget-grafana-plugins/scripted-datasource-plugin.1.3.4.zip
RUN unzip scripted-datasource-plugin.1.3.4.zip && \
    rm scripted-datasource-plugin.1.3.4.zip

# get remote queries
RUN mkdir /scripted-queries
WORKDIR /scripted-queries
RUN wget https://dx-nexus.metroscales.io/repository/errorbudget-grafana-plugins/oma-queries.1.0.3.zip
RUN unzip oma-queries.1.0.3.zip && \
    rm oma-queries.1.0.3.zip

RUN cp -TRv /scripted-queries/dist/ /scripted-datasource/dist/queries/

# get echarts plugin
RUN mkdir /echarts
WORKDIR /echarts
RUN wget https://dx-nexus.metroscales.io/repository/errorbudget-grafana-plugins/echarts-plugin.1.3.3.zip
RUN unzip echarts-plugin.1.3.3.zip && \
    rm echarts-plugin.1.3.3.zip

# add oma widgets to echarts
RUN mkdir -p /oma-widgets
WORKDIR /oma-widgets
RUN wget https://dx-nexus.metroscales.io/repository/errorbudget-grafana-plugins/oma-widgets.1.2.15.zip
RUN unzip oma-widgets.1.2.15.zip && \
    rm oma-widgets.1.2.15.zip

RUN mkdir -p /echarts/dist/widgets/
RUN cp -TRv /oma-widgets/dist/ /echarts/dist/widgets/

# get CF plugin
RUN mkdir /cf-plugin
WORKDIR /cf-plugin
RUN wget https://dx-nexus.metroscales.io/repository/errorbudget-grafana-plugins/cf-plugin.1.0.13.zip
RUN unzip cf-plugin.1.0.13.zip && \
    rm cf-plugin.1.0.13.zip

# get slo plugin
RUN mkdir /slo-plugin
WORKDIR /slo-plugin
RUN wget https://dx-nexus.metroscales.io/repository/errorbudget-grafana-plugins/oma-slo-plugin.1.1.2.zip
RUN unzip oma-slo-plugin.1.1.2.zip && \
    rm oma-slo-plugin.1.1.2.zip

# get DevOps-Metrics plugin
RUN mkdir /devops-metrics
WORKDIR /devops-metrics
RUN wget https://dx-nexus.metroscales.io/repository/errorbudget-grafana-plugins/devops-metrics-plugin.1.1.7.zip
RUN unzip devops-metrics-plugin.1.1.7.zip && \
    rm devops-metrics-plugin.1.1.7.zip

WORKDIR /metro-plugin
RUN npx @grafana/toolkit@8.2.2 plugin:sign --rootUrls https://oma.metro.digital,https://oma-pp.metro.digital,${LOCAL_ADRESS}

WORKDIR /oma-config
RUN npx @grafana/toolkit@8.2.2 plugin:sign --rootUrls https://oma.metro.digital,https://oma-pp.metro.digital,${LOCAL_ADRESS}

WORKDIR /oma-sda-dashboards
RUN npx @grafana/toolkit@8.2.2 plugin:sign --rootUrls https://oma.metro.digital,https://oma-pp.metro.digital,${LOCAL_ADRESS}

WORKDIR /scripted-datasource
RUN npx @grafana/toolkit@8.2.2 plugin:sign --rootUrls https://oma.metro.digital,https://oma-pp.metro.digital,${LOCAL_ADRESS}

WORKDIR /echarts
RUN npx @grafana/toolkit@8.2.2 plugin:sign --rootUrls https://oma.metro.digital,https://oma-pp.metro.digital,${LOCAL_ADRESS}

WORKDIR /slo-plugin
RUN npx @grafana/toolkit@8.2.2 plugin:sign --rootUrls https://oma.metro.digital,https://oma-pp.metro.digital,${LOCAL_ADRESS}

WORKDIR /cf-plugin
RUN npx @grafana/toolkit@8.2.2 plugin:sign --rootUrls https://oma.metro.digital,https://oma-pp.metro.digital,${LOCAL_ADRESS}

WORKDIR /devops-metrics
RUN npx @grafana/toolkit@8.2.2 plugin:sign --rootUrls https://oma.metro.digital,https://oma-pp.metro.digital,${LOCAL_ADRESS}

FROM registry.metroscales.io/errorbudget/grafana:8.2.2n

COPY --from=builder /datadog/dist /var/lib/grafana/plugins/datadog
COPY --from=builder /piechart-panel/grafana-piechart-panel /var/lib/grafana/plugins/piechart-panel
COPY --from=builder /github-datasource/grafana-github-datasource /var/lib/grafana/plugins/github-datasource
COPY --from=builder /metro-plugin/dist /var/lib/grafana/plugins/metro
COPY --from=builder /oma-config/dist /var/lib/grafana/plugins/oma-config
COPY --from=builder /oma-sda-dashboards/dist /var/lib/grafana/plugins/oma-sda-dashboards
COPY --from=builder /scripted-datasource/dist /var/lib/grafana/plugins/scripted-datasource
COPY --from=builder /echarts/dist /var/lib/grafana/plugins/echarts
COPY --from=builder /cf-plugin/dist /var/lib/grafana/plugins/cf-plugin
COPY --from=builder /slo-plugin/dist /var/lib/grafana/plugins/slo-plugin
COPY --from=builder /devops-metrics/dist /var/lib/grafana/plugins/4keys
COPY --from=builder /bigquery-datasource /var/lib/grafana/plugins/bigquery-datasource

COPY /provisioning/dashboards /etc/grafana/provisioning/dashboards
COPY /provisioning/public /usr/share/grafana/public
