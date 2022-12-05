#!/usr/bin/env bash
set -eo pipefail

MINIKUBE_IP=$(minikube ip)
GF_CONTROLLER_URL="http://$MINIKUBE_IP:30005"
GF_URL="http://$MINIKUBE_IP:30000"
ES_URL="http://$MINIKUBE_IP:30008"
ELASTIC_TO_COPY_URL="http://essa0-essa-live3-msys-be-gcw1.metroscales.io:9200"

DS_ELASTIC_URL="http://elastic:9200"
DS_DATADOG_URL="https://metrodigital.datadoghq.eu/api/v1"

## datasource IDs
elasticDatasourceId=-1
datadogDatasourceId=-1

# import other than errorbudget
# for some cases sda config needs to be updated in initOrgWithPlugin
SDA_INDEX_IMPORT_DAYS=30
TestOrgName="errorbudget"
ORG_ID_TO_IMPORT=45


CREATED_ORG_ID=-1

function die () {
  echo "$@"
  exit 1
}

function main {
  case "${1:-}" in

  insertMetrics) insertMetrics "${@:2}";;
  importSda) importSda;;
  *)
    help
    exit 1
    ;;

  esac
}

function help {
  echo "Usage:"
  echo " insertMetrics                  create test metrics"
  echo " importSda                      import SDA data from PP ELK to local ELK"
  echo
}


function minikube {
  echo "Deploy on minikube"
}

function metro {
  if [ "$#" -ne 1 ]; then
    die "Command expects 1 argument: namespace"
  fi
  echo "Deploy on metro [$1]"
}

function insertMetrics() {
  source datadog_secrets.sh
  waitForGrafana

  waitForElastic

  createRecommendationIndex

  initDefaultOrg

  initOrgWithPlugin $TestOrgName

  waitForCruiser
  
  # init solutions
  echo "Importing solutions"
  img_id=$(docker ps | grep -i postgres_postgres | cut -d' ' -f1)
  docker cp migration/solutions.sql "$img_id":/
  docker cp migration/datasource_solution.sql "$img_id":/

  docker exec --user postgres $img_id sh -c "psql -d grafana -a -f /solutions.sql"
  docker exec --user postgres $img_id sh -c "psql -d grafana -a -f /datasource_solution.sql"
  docker exec --user postgres $img_id sh -c "psql -d grafana -c \"UPDATE public.org SET product_id=68 WHERE "name"='errorbudget';\""
  
  SLO_ID_11=$(createDDSlo "$CREATED_ORG_ID" "DX :: OMA :: grafana SLO on live3" "99" "0" "aa9aa72dedac5e1dab3f4925e00ceacd" "monitor" "$datadogDatasourceId" false)
  echo "CREATED DD SLO: $SLO_ID_11"
  
  SLO_ID_12=$(createDDSlo "$CREATED_ORG_ID" "DX :: OMA :: grafana response codes on live3" "0" "99" "3adcc08c0c785103beae891fc7675ca4" "metric" "$datadogDatasourceId" false)
  echo "CREATED DD SLO: $SLO_ID_12" 
  
  SLO_ID_13=$(createDDSlo "$CREATED_ORG_ID" "DX :: OMA :: Sonarqube SLO on live3" "99" "0" "b059c44782815c63a76a23a871eaa5ab" "monitor" "$datadogDatasourceId" true "77")
  echo "CREATED DD SLO: $SLO_ID_13"

  SLO_ID_14=$(createDDSlo "$CREATED_ORG_ID" "DX :: OMA :: analytics SLO on live3" "99" "0" "cc80e3a7590452e1b9f0278084931f61" "monitor" "$datadogDatasourceId" true "77")
  echo "CREATED DD SLO: $SLO_ID_14"
}

function createOrg() {
  orgName=$1
  BODY='{
      "name": "'$orgName'"
  }'
  RESPONSE=$(curl -b admin-cookie.txt -s \
    "$GF_URL"/api/orgs \
    -H "Content-Type: application/json" \
    -d "$BODY")

  echo "$RESPONSE" | jq -r '.orgId'
}

function waitForGrafana() {
  while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' $GF_URL/api/health)" != "200" ]]; do echo "wait for grafana..."; sleep 2; done
}

function waitForElastic() {
  while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' $ES_URL/_cluster/health)" != "200" ]]; do echo "wait for elastic..."; sleep 2; done
  sleep 2
}

function waitForCruiser() {
  while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' $GF_CONTROLLER_URL/openapi/doc.json)" != "200" ]]; do echo "wait for cruiser..."; sleep 2; done
  sleep 2
}

function createRecommendationIndex() {
  RESPONSE=$(curl -s -X PUT \
  "$ES_URL/recommendation?include_type_name=true" \
  -H 'Content-Type: application/json' \
  -d '{
        "mappings": {
            "_doc": {
                "properties": {
                    "category": {
                        "type": "text",
                        "fields": {
                            "keyword": {
                                "type": "keyword",
                                "ignore_above": 256
                            }
                        }
                    },
                    "link": {
                        "type": "text",
                        "fields": {
                            "keyword": {
                                "type": "keyword",
                                "ignore_above": 256
                            }
                        }
                    },
                    "orgId": {
                        "type": "long"
                    },
                    "priority": {
                        "type": "long"
                    },
                    "tags": {
                        "type": "text",
                        "fields": {
                            "keyword": {
                                "type": "keyword",
                                "ignore_above": 256
                            }
                        }
                    },
                    "text": {
                        "type": "text",
                        "fields": {
                            "keyword": {
                                "type": "keyword",
                                "ignore_above": 256
                            }
                        }
                    },
                    "time": {
                        "type": "date"
                    },
                    "title": {
                        "type": "text",
                        "fields": {
                            "keyword": {
                                "type": "keyword",
                                "ignore_above": 256
                            }
                        }
                    }
                }
            }
        }
    }')
 echo "Creating Elastic index response:  $RESPONSE "
}

function initDataDog() {
  orgID=$1
   BODY='{
      "name": "DataDog-EU",
      "type": "datadog",
      "url": "'$DS_DATADOG_URL'",
      "access": "proxy",
      "basicAuth": false,
      "isDefault": false,
      "jsonData": {
        "app_key": "'$DS_DATADOG_APP_KEY'",
        "api_key": "'$DS_DATADOG_API_KEY'"
      }
  }'
  RESPONSE=$(curl -b admin-cookie.txt -s \
    "$GF_URL"/api/datasources \
    -H "Content-Type: application/json" \
    -H "X-Grafana-Org-Id: $orgID" \
    -d "$BODY")
  echo "$RESPONSE" | jq -r '.id'
}

function initLocalElastic {
  orgID=$1
  echo $(initElastic $orgID 'elasticsearch localhost' 'docker-loadbalancer-*' '@timestamp')
}

function initElastic() {
  orgID=$1
  name=$2
  databse=$3
  timeField=$4
   BODY='{
      "name": "'$name'",
      "type": "elasticsearch",
      "url": "'$DS_ELASTIC_URL'",
      "access": "proxy",
      "database": "'$databse'",
      "basicAuth": false,
      "withCredentials": false,
      "jsonData": {
        "timeInterval": "",
        "timeField": "'$timeField'",
        "esVersion": 70,
        "maxConcurrentShardRequests": 5,
        "tlsAuth": false,
        "tlsAuthWithCACert": false
      }
  }'
  RESPONSE=$(curl -b admin-cookie.txt -s \
    "$GF_URL"/api/datasources \
    -H "Content-Type: application/json" \
    -H "X-Grafana-Org-Id: $orgID" \
    -d "$BODY")

  echo "$RESPONSE" | jq -r '.id'
}

function initPostgresDS() {
  orgID=$1
   BODY='{
      "name": "oma-pgsql",
      "type": "postgres",
      "typeName": "PostgreSQL",
      "access": "proxy",
      "url": "postgres:5432",
      "password": "readonly",
      "user": "grafana_datasource",
      "database": "grafana",
      "basicAuth": false,
      "jsonData": {
          "maxOpenConns": 10,
          "postgresVersion": 1000,
          "sslmode": "disable",
          "tlsAuth": false,
          "tlsAuthWithCACert": false,
          "tlsConfigurationMethod": "file-path",
          "tlsSkipVerify": true
      }
  }'
  RESPONSE=$(curl -b admin-cookie.txt -s \
    "$GF_URL"/api/datasources \
    -H "Content-Type: application/json" \
    -H "X-Grafana-Org-Id: $orgID" \
    -d "$BODY")

  echo "$RESPONSE" | jq -r '.id'
}

function createDDSlo() {
  BODY='{
      "orgId": '$1',
      "name": "'$2'",
      "complianceExpAvailability": "'$3'",
      "successRateExpAvailability": "'$4'", 
      "externalId": "'$5'",
      "externalType": "'$6'",
      "datasourceId": '$7',
      "critical": '$8',
      "externalSla": "'$9'"
    }'

  RESPONSE=$(curl -b admin-cookie.txt -s -X POST \
    "$GF_CONTROLLER_URL"/v1/slo \
    -H "Content-Type: application/json" \
    -d "$BODY")

  echo "$RESPONSE" | jq -r '.id'
}

function initElastic() {
  orgID=$1
  name=$2
  databse=$3
  timeField=$4
   BODY='{
      "name": "'$name'",
      "type": "elasticsearch",
      "url": "'$DS_ELASTIC_URL'",
      "access": "proxy",
      "database": "'$databse'",
      "basicAuth": false,
      "withCredentials": false,
      "jsonData": {
        "timeInterval": "",
        "timeField": "'$timeField'",
        "esVersion": 70,
        "maxConcurrentShardRequests": 5,
        "tlsAuth": false,
        "tlsAuthWithCACert": false
      }
  }'
  RESPONSE=$(curl -s \
    "$GF_URL"/api/datasources -b admin-cookie.txt \
    -H "Content-Type: application/json" \
    -H "X-Grafana-Org-Id: $orgID" \
    -d "$BODY")

  echo "$RESPONSE" | jq -r '.id'
}

function initOrgWithPlugin() {
  ORG_NAME=$1

  echo "ORG_NAME:: $ORG_NAME"

  # create org
  CREATED_ORG_ID=$(createOrg "$ORG_NAME")
  echo "Created Org ID:" $CREATED_ORG_ID

  # enable plugin (cruiser API)
  curl -b admin-cookie.txt -s \
    --request POST "$GF_URL"/ebt/v1/plugin/"$CREATED_ORG_ID" \
    -H "X-Grafana-Org-Id: $CREATED_ORG_ID"

  # SDA config
  echo -e "\n"
  echo "Configure SDA"
  curl -b admin-cookie.txt -s \
    --request POST "$GF_URL"/api/user/using/"$CREATED_ORG_ID" \
    -H 'Content-Type: application/json' \
    -H 'X-Grafana-Org-Id: 1'

  echo -e "\n"
  curl -b admin-cookie.txt -s \
    --request POST "$GF_URL"/api/plugins/oma-slo-plugin/settings \
    -H 'Authorization: Basic YWRtaW46YWRtaW4=' \
    -H 'Content-Type: application/json' \
    -H 'X-Grafana-Org-Id: $CREATED_ORG_ID' \
    --data-raw '{"enabled":true,"pinned":true,"jsonData":null}'

  echo -e "\n"
  curl -b admin-cookie.txt -s \
    --request POST "$GF_URL"/api/plugins/devops-metrics-plugin/settings \
    -H 'Authorization: Basic YWRtaW46YWRtaW4=' \
    -H 'Content-Type: application/json' \
    -H 'X-Grafana-Org-Id: $CREATED_ORG_ID' \
    --data-raw '{"enabled":true,"pinned":true,"jsonData":null}'
    
  echo -e "\n"
  curl -b admin-cookie.txt -s \
    --request POST "$GF_URL"/api/plugins/grafana-cf-app/settings \
    -H 'Authorization: Basic YWRtaW46YWRtaW4=' \
    -H 'Content-Type: application/json' \
    -H 'X-Grafana-Org-Id: $CREATED_ORG_ID' \
    --data-raw '{"enabled":true,"pinned":true,"jsonData":null}'
    
  echo -e "\n"
  curl -b admin-cookie.txt -s \
    --request POST "$GF_URL"/api/plugins/grafana-tutorial-app/settings \
    -H 'Authorization: Basic YWRtaW46YWRtaW4=' \
    -H 'Content-Type: application/json' \
    -H 'X-Grafana-Org-Id: $CREATED_ORG_ID' \
    --data-raw '{"enabled":true,"pinned":true,"jsonData":null}'

  echo -e "\n"
  curl -b admin-cookie.txt -s \
    --request POST "$GF_URL"/api/plugins/grafana-eb-app/settings \
    -H 'Authorization: Basic YWRtaW46YWRtaW4=' \
    -H 'Content-Type: application/json' \
    -H 'X-Grafana-Org-Id: $CREATED_ORG_ID' \
    --data-raw '{
          "enabled": true,
          "pinned": true,
          "jsonData": {
            "recommendations": {
              "levelEnabled": {
                "high": true,
                "medium": true,
                "low": true
              }
            },
            "sda": {
              "enabled": true,
              "sharing_allowed": true,
              "git_autodiscover": true,
              "git_team": "product_oma",
              "harbor_project": "'"${TestOrgName}"'",              
              "git": [
                {
                  "url": "git@github.com:metro-digital-inner-source/errorbudget-prometheus-playground.git"
                },
                {
                  "url": "git@github.com:metro-digital-inner-source/errorbudget-sda.git"
                },
                {
                  "url": "git@github.com:metro-digital-inner-source/errorbudget-susie.git"
                },
                {
                  "url": "git@github.com:metro-digital-inner-source/errorbudget-stratford.git"
                },
                {
                  "url":"git@github.com:metro-digital-inner-source/errorbudget-sda-sidecar.git"
                },
                {
                  "url":"git@github.com:metro-digital-inner-source/errorbudget-analytics.git"
                },
                {
                  "url":"git@github.com:metro-digital-inner-source/echarts-grafana-plugin.git"
                },
                {
                  "url":"git@github.com:metro-digital-inner-source/grafana-metro-plugin.git"
                },
                {
                  "url":"git@github.com:metro-digital-inner-source/scripted-datasource-plugin.git"
                },
                {
                  "url":"git@github.com:metro-digital-inner-source/oma-config-plugin"
                },
                {
                  "url":"git@github.com:metro-digital-inner-source/errorbudget-images.git"
                }
              ],
              "cicd": [],
              "jira": [
                {
                  "project": "OPEB",
                  "url": "https://jira.metrosystems.net"
                }
              ],
              "sonarqube": [
                {
                  "project":"errorbudget-susie",
                  "qualifier":"TRK",
                  "url":"https://sonarqube.metrosystems.net"
                },
                {
                  "project":"oma",
                  "qualifier":"APP",
                  "url":"https://sonarqube.metrosystems.net"
                },
                {
                  "project":"errorbudget-sda",
                  "qualifier":"TRK",
                  "url":"https://sonarqube.metrosystems.net"
                }
              ]
            }
          }
        }'

  echo -e "\n"
  curl -b admin-cookie.txt -s \
    --request POST "$GF_URL"/api/plugins/oma-sda-dashboards/settings \
    -H 'Authorization: Basic YWRtaW46YWRtaW4=' \
    -H 'Content-Type: application/json' \
    -H 'X-Grafana-Org-Id: $CREATED_ORG_ID' \
    --data-raw '{"enabled":true,"pinned":true,"jsonData":null}'

  echo -e "\n"
  # list datasources
  DATASOURCES=$(curl -b admin-cookie.txt -s \
    "$GF_URL"/api/datasources \
    -H "X-Grafana-Org-Id: $CREATED_ORG_ID")

  # FIND DS IDs
  datadogDatasourceId=$(echo "$DATASOURCES" | jq '.[] | select(.name=="DataDog-EU") | .id')
  echo "DataDog Datasource ID: $datadogDatasourceId"
  
  # Create additional DS
  elasticDatasourceId=$(initLocalElastic "$CREATED_ORG_ID")
  echo "Elastic Datasource ID: $elasticDatasourceId"
}

function initDefaultOrg() {
  # log in
  curl --cookie-jar admin-cookie.txt \
    --request POST $GF_URL'/login' \
    --header 'Content-Type: application/json' --data-raw '{
      "user": "admin",
      "password": "admin",
      "email": ""
  }'

  echo "Logged In"

  echo "Init default org"

  #Enable plugin

  # enable plugin (cruiser API)
  echo -e "\n"
  curl -b admin-cookie.txt -s \
    --request POST "$GF_URL"/ebt/v1/plugin/1 \
    -H "X-Grafana-Org-Id: 1"

  echo -e "\n"
  curl -b admin-cookie.txt -s \
    --request POST "$GF_URL"/api/plugins/grafana-metro-app/settings \
    -H 'Content-Type: application/json' \
    -H 'X-Grafana-Org-Id: 1' \
    --data-raw '{"enabled":true,"pinned":true,"jsonData":null}'

  # Create additional DS
  postgresDatasourceId=$(initPostgresDS "1")
  echo "Postgres Datasource ID: $postgresDatasourceId"

  # Init team
  echo -e 'Init team\n'
  RESPONSE=$(curl -b admin-cookie.txt -s \
    --request POST "$GF_URL"/api/teams \
    -H 'Content-Type: application/json' \
    -H "X-Grafana-Org-Id: 1"\
    --data-raw '{ "Name": "Metro digital engineering management", "orgId": 1 }')
  teamId=`echo $RESPONSE | jq -r '.teamId'`

  # Add Admin user to team
  echo -e "\n"
  curl -b admin-cookie.txt -s \
    --request POST "$GF_URL"/api/teams/"$teamId"/members \
    -H 'Content-Type: application/json' \
    -H "X-Grafana-Org-Id: 1"\
    --data-raw '{ "userId": 1 }'

  # Disable oma plugin
  echo -e "\n"
  curl -b admin-cookie.txt -s \
    --request POST "$GF_URL"/api/plugins/grafana-eb-app/settings \
    -H 'Content-Type: application/json' \
    -H 'X-Grafana-Org-Id: 1' \
    --data-raw '{"enabled":false,"pinned":false,"jsonData":null}'
}

function importSda() {
  copyIndex sda_errorbudget_jenkins
  copyIndex sda_errorbudget_jira
  copyIndex sda_errorbudget_gitlab
  copyIndex sda_errorbudget_github
  copyIndex sda_errorbudget_githubactions
  copyIndex sda_errorbudget_git
  copyIndex sda_errorbudget_git_raw  
  copyIndex sda_errorbudget_sonarqube

  copyHistoricalDataFromDateIndex oma-deployments-info 2
  copyHistoricalDataFromDateIndex oma-deployments-changeset 2
  copyHistoricalDataFromDateIndex oma-issues 2
  copyHistoricalDataFromDateIndex oma-metrics 2
  echo -e "    Done"
}

function copyHistoricalDataFromDateIndex() {
  local indexToCopy=$1
  monthAmount=$2
  echo -e "Copying #months ${monthAmount} of index $idx"
   for (( i=0; i<=$monthAmount; i++ ))
    do
      if [ "$(uname)" == "Darwin" ]; then
      SYS_PATTERN="-v "-${i}m""
      else
      SYS_PATTERN="--date='-$i month'"
      fi

      PATTERN="date $SYS_PATTERN '+%Y-%m'"
      date_suffix=$(eval $PATTERN)
      copyIndexWithOrgIDUpdate "$indexToCopy"-"$date_suffix"
    done
}

function copyIndex() {
  idx=$1
  echo -e "Index ${idx}"

  MAPPING_JSON=$(curl -s -X GET "${ELASTIC_TO_COPY_URL}/${idx}/_mapping?include_type_name=true" | jq ".[\"${idx}\"]")
  RESPONSE=$(curl -s --header "Content-Type: application/json" -X PUT \
    -d "${MAPPING_JSON}" \
    "${ES_URL}/${idx}?include_type_name=true")
  echo "$RESPONSE"

  RESPONSE=$(curl --location --request POST -s "${ES_URL}/_reindex" \
  --header 'Content-Type: application/json' \
  --data-raw '{
      "source": {
          "remote": {
              "host": "'${ELASTIC_TO_COPY_URL}'"
          },
          "index": "'${idx}'",
          "query": {"bool":{"must":[{"range":{"metadata__updated_on":{"gte":"now-'${SDA_INDEX_IMPORT_DAYS}'d","lte":"now","format":"epoch_millis"}}}]}}
      },
      "dest": {
          "index": "'${idx}'"
      }
  }')
  echo -n 'items '
  echo -n "$RESPONSE" | jq -r '.total'
}

function copyIndexWithOrgIDUpdate() {
  idx=$1
  echo -e "Index ${idx}"

  MAPPING_JSON=$(curl -s -X GET "${ELASTIC_TO_COPY_URL}/${idx}/_mapping?include_type_name=true" | jq ".[\"${idx}\"]")
  RESPONSE=$(curl -s --header "Content-Type: application/json" -X PUT \
    -d "${MAPPING_JSON}" \
    "${ES_URL}/${idx}?include_type_name=true")
  echo "$RESPONSE"


  RESPONSE=$(curl --location --request POST -s "${ES_URL}/_reindex" \
  --header 'Content-Type: application/json' \
  --data-raw '{
      "source": {
          "remote": {
              "host": "'${ELASTIC_TO_COPY_URL}'"
          },
          "index": "'${idx}'",
          "query": {"bool":{"must":[{"term":{"orgId":"'${ORG_ID_TO_IMPORT}'"}}]}}
      },
      "dest": {
          "index": "'${idx}'"
      },
      "script": {
        "source": "ctx._source.orgId=2",
        "lang": "painless"
      }
  }')
  echo -n 'items '
  echo -n "$RESPONSE" | jq -r '.total'
}

main "$@"
