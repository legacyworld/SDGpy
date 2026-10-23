# Set up environment
set -a
. /home/kubernetes-vm/env
set +a
ELASTICSEARCH_URL="https://es.elastic.lab"
KIBANA_URL="https://kb.elastic.lab"

BASE64=$(echo -n "elastic:${ELASTICSEARCH_PASSWORD}" | base64)
KIBANA_URL_WITHOUT_PROTOCOL=$(echo $KIBANA_URL | sed -e 's#http[s]\?://##g')

# Add sdg user with superuser role
curl -X POST "https://es.elastic.lab/_security/user/sdg" -H "Content-Type: application/json" -u "elastic:${ELASTICSEARCH_PASSWORD}" -d '{
  "password" : "changeme",
  "roles" : [ "superuser" ],
  "full_name" : "SDG User",
  "email" : "sdg@elastic-pahlsoft.com"
}'

# Install LLM Connector
#bash /opt/workshops/elastic-llm.sh -k false -m claude-sonnet-4 -d true
bash /opt/workshops/elastic-llm.sh -k false -m claude-sonnet-4 -d true

echo
#echo "AWS Bedrock AI Assistant Connector configured as OpenAI"
echo "AI Assistant Connector configured as Claude 4.0"
echo

echo "Loading pre-built Elastic Security rules..."
echo
echo "Please, stand-by."
# Load pre-built Elastic Security rules
curl -X PUT "https://kb.elastic.lab/api/detection_engine/rules/prepackaged" -u "sdg:changme"  --header "kbn-xsrf: true" -H "Content-Type: application/json"  -d '{}'

clear

echo
echo
echo
echo
echo "Welcome to the kitchen!!!!"
