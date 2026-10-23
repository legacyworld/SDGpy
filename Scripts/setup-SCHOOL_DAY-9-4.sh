# Set up environment
set -a
. /home/kubernetes-vm/env
set +a
ELASTICSEARCH_URL="https://es.elastic.lab"
KIBANA_URL="https://kb.elastic.lab"

BASE64=$(echo -n "elastic:${ELASTICSEARCH_PASSWORD}" | base64)
KIBANA_URL_WITHOUT_PROTOCOL=$(echo $KIBANA_URL | sed -e 's#http[s]\?://##g')

echo "Waiting for Elasticsearch at ${ELASTICSEARCH_URL}..."

MAX_RETRIES=60
RETRY=0

until [ "$RETRY" -ge "$MAX_RETRIES" ]
do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -u "elastic:${ELASTICSEARCH_PASSWORD}" \
        "${ELASTICSEARCH_URL}/")

    if [ "$HTTP_CODE" = "200" ]; then
        echo "Elasticsearch is available."
        break
    fi

    RETRY=$((RETRY+1))
    echo "Elasticsearch not ready yet (HTTP ${HTTP_CODE}). Retry ${RETRY}/${MAX_RETRIES}..."
    sleep 5
done

if [ "$RETRY" -eq "$MAX_RETRIES" ]; then
    echo "ERROR: Elasticsearch did not become available after $((MAX_RETRIES * 5)) seconds."
    exit 1
fi


# Add sdg user with superuser role
curl -X POST "https://es.elastic.lab/_security/user/sdg" -H "Content-Type: application/json" -u "elastic:${ELASTICSEARCH_PASSWORD}" -d '{
  "password" : "changeme",
  "roles" : [ "superuser" ],
  "full_name" : "SDG User",
  "email" : "sdg@elastic-pahlsoft.com"
}'


# Install LLM Connector
#bash /opt/workshops/elastic-llm.sh -m gpt-5.5 -k false -d true 

#echo
#echo "OpenAI Connector configured"
#echo

# Use Security view
bash /opt/workshops/elastic-view.sh -v classic

echo
echo "Default Kibana view applied"
echo

# Create Elastic-Agent policies
curl -X POST "https://kb.elastic.lab/api/fleet/agent_policies?sys_monitoring=true" --header "kbn-xsrf: true"  -H "Content-Type: application/json" -u "sdg:changeme" -d @/home/elastic/SDGpy/Agent-Policies/Infra.json
curl -X POST "https://kb.elastic.lab/api/fleet/agent_policies?sys_monitoring=true" --header "kbn-xsrf: true"  -H "Content-Type: application/json" -u "sdg:changeme" -d @/home/elastic/SDGpy/Agent-Policies/SecOps.json

echo
echo "Elastic-Agent policies Infrastructure & SecOps created"
echo

# Create Entity Asset lists
curl -X POST "https://kb.elastic.lab/api/asset_criticality/bulk" --header "kbn-xsrf: true"  -H "Content-Type: application/json" -u "sdg:changeme" -d @/home/elastic/SDGpy/Entity-Asset-List/entities-v1.json

echo
echo "Entity Asset list loaded"
echo

# Load index templates for enrichment data
curl -X POST "https://es.elastic.lab/_index_template/enrich-bluecoat" -H "Content-Type: application/json" -u "sdg:changeme" -d @/home/elastic/SDGpy/Index-Templates/Enrichment-Index-Templates/enrich-bluecoat.json
curl -X POST "https://es.elastic.lab/_index_template/enrich-nginx" -H "Content-Type: application/json" -u "sdg:changeme" -d @/home/elastic/SDGpy/Index-Templates/Enrichment-Index-Templates/enrich-nginx.json
curl -X POST "https://es.elastic.lab/_index_template/enrich-rip" -H "Content-Type: application/json" -u "sdg:changeme" -d @/home/elastic/SDGpy/Index-Templates/Enrichment-Index-Templates/enrich-rip.json
curl -X POST "https://es.elastic.lab/_index_template/enrich-user_agents" -H "Content-Type: application/json" -u "sdg:changeme" -d @/home/elastic/SDGpy/Index-Templates/Enrichment-Index-Templates/enrich-user_agents.json
curl -X POST "https://es.elastic.lab/_index_template/enrich-windows.sysmon_operational" -H "Content-Type: application/json" -u "sdg:changeme" -d @/home/elastic/SDGpy/Index-Templates/Enrichment-Index-Templates/enrich-windows.sysmon_operational.json

echo
echo "Enrichment index templates loaded"
echo

# Load enrichment data sources
curl -X POST "https://es.elastic.lab/enrich-windows.sysmon_operational/_bulk" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" --data-binary @/home/elastic/SDGpy/Enrichment-Data/enrich-windows.sysmon_operational.ndjson
curl -X POST "https://es.elastic.lab/enrich-rip/_bulk" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" --data-binary @/home/elastic/SDGpy/Enrichment-Data/enrich-rip.ndjson
curl -X POST "https://es.elastic.lab/enrich-bluecoat/_bulk" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" --data-binary @/home/elastic/SDGpy/Enrichment-Data/enrich-bluecoat.ndjson
curl -X POST "https://es.elastic.lab/enrich-nginxv2/_bulk" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" --data-binary @/home/elastic/SDGpy/Enrichment-Data/enrich-nginxv2.ndjson
curl -X POST "https://es.elastic.lab/enrich-user_agents/_bulk" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" --data-binary @/home/elastic/SDGpy/Enrichment-Data/enrich-user_agents.ndjson

echo
echo "Enrichment data loaded"
echo

# Create enrichment policies
curl -X PUT "https://es.elastic.lab/_enrich/policy/enrich-bluecoat" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" --data-binary @/home/elastic/SDGpy/Enrichment-Policies/enrich-bluecoat.json
curl -X PUT "https://es.elastic.lab/_enrich/policy/enrich-nginx" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" --data-binary @/home/elastic/SDGpy/Enrichment-Policies/enrich-nginx.json
curl -X PUT "https://es.elastic.lab/_enrich/policy/enrich-windows.sysmon_operational" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" --data-binary @/home/elastic/SDGpy/Enrichment-Policies/enrich-windows.sysmon_operational.json
curl -X PUT "https://es.elastic.lab/_enrich/policy/remote-ips" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" --data-binary @/home/elastic/SDGpy/Enrichment-Policies/remote-ips.json
curl -X PUT "https://es.elastic.lab/_enrich/policy/user-agents" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" --data-binary @/home/elastic/SDGpy/Enrichment-Policies/user-agents.json

echo
echo "Enrichment policies loaded"
echo

# Execute enrichment policies
curl -X POST "https://es.elastic.lab/_enrich/policy/enrich-windows.sysmon_operational/_execute" -u "sdg:changeme"
curl -X POST "https://es.elastic.lab/_enrich/policy/remote-ips/_execute" -u "sdg:changeme"
curl -X POST "https://es.elastic.lab/_enrich/policy/enrich-bluecoat/_execute" -u "sdg:changeme"
curl -X POST "https://es.elastic.lab/_enrich/policy/enrich-nginx/_execute" -u "sdg:changeme"
curl -X POST "https://es.elastic.lab/_enrich/policy/user-agents/_execute" -u "sdg:changeme"

echo
echo "Enrichment policies executed"
echo

# Creat ingest pipelines
curl -X PUT "https://es.elastic.lab/_ingest/pipeline/logs-windows.sysmon_operational" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" -d @/home/elastic/SDGpy/Ingest-Pipelines/logs-windows.sysmon_operational.json
curl -X PUT "https://es.elastic.lab/_ingest/pipeline/logs-ti_abusech.malware@custom" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" -d @/home/elastic/SDGpy/Ingest-Pipelines/logs-ti_abusech.malware@custom.json
curl -X PUT "https://es.elastic.lab/_ingest/pipeline/email-filter-rules" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" -d @/home/elastic/SDGpy/Ingest-Pipelines/email-filter-rules.json
curl -X PUT "https://es.elastic.lab/_ingest/pipeline/enrich-bluecoat" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" -d @/home/elastic/SDGpy/Ingest-Pipelines/enrich-bluecoat.json
curl -X PUT "https://es.elastic.lab/_ingest/pipeline/enrich-email" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" -d @/home/elastic/SDGpy/Ingest-Pipelines/enrich-email.json
curl -X PUT "https://es.elastic.lab/_ingest/pipeline/enrich-logs-network_traffic-dns" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" -d @/home/elastic/SDGpy/Ingest-Pipelines/enrich-logs-network_traffic-dns.json
curl -X PUT "https://es.elastic.lab/_ingest/pipeline/enrich-logs-network_traffic" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" -d @/home/elastic/SDGpy/Ingest-Pipelines/enrich-logs-network_traffic.json
curl -X PUT "https://es.elastic.lab/_ingest/pipeline/enrich-nginx" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" -d @/home/elastic/SDGpy/Ingest-Pipelines/enrich-nginx.json
curl -X PUT "https://es.elastic.lab/_ingest/pipeline/logs-network_traffic-cleanup" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" -d @/home/elastic/SDGpy/Ingest-Pipelines/logs-network_traffic-cleanup.json
curl -X PUT "https://es.elastic.lab/_ingest/pipeline/nginx-cleanup" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" -d @/home/elastic/SDGpy/Ingest-Pipelines/nginx-cleanup.json
curl -X PUT "https://es.elastic.lab/_ingest/pipeline/timestamp-cleanup" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" -d @/home/elastic/SDGpy/Ingest-Pipelines/timestamp-cleanup.json
curl -X PUT "https://es.elastic.lab/_ingest/pipeline/logs-proxysg.log" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" -d @/home/elastic/SDGpy/Ingest-Pipelines/logs-proxysg.log.json
curl -X PUT "https://es.elastic.lab/_ingest/pipeline/logs-netflow.log" -H "Content-Type: application/x-ndjson" -u "sdg:changeme" -d @/home/elastic/SDGpy/Ingest-Pipelines/logs-netflow.log.json

echo
echo "Custom Ingest Pipelines loaded"
echo

# Enable beta integrations
curl -u "sdg:changeme" -X PUT https://kb.elastic.lab/api/fleet/settings -H "kbn-xsrf: true" -H "Content-Type: application/json" -d '{"prerelease_integrations_enabled": true}'

# Load pre-built Elastic Security rules (not required for this lab)
#curl -X PUT "https://kb.elastic.lab/api/detection_engine/rules/prepackaged" -u "sdg:changme"  --header "kbn-xsrf: true" -H "Content-Type: application/json"  -d '{}'

clear

echo
echo
echo
echo "You are now ready to begin the assignment."
