SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

####################################################################### ENV

ENV_FILE=/home/kubernetes-vm/env

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: Environment file not found: $ENV_FILE"
    exit 1
fi

set -a
. /home/kubernetes-vm/env
set +a

if [ -z "$ELASTICSEARCH_PASSWORD" ]; then
    echo "ERROR: ELASTICSEARCH_PASSWORD not found in $ENV_FILE"
    exit 1
fi

ELASTICSEARCH_URL="https://es.elastic.lab"

####################################################################### CREATE USER

MAX_ATTEMPTS=10
RETRY_INTERVAL=5

echo "=========================================="
echo "Creating Elasticsearch user: sdg"
echo "Elasticsearch URL: $ELASTICSEARCH_URL"
echo "Max attempts: $MAX_ATTEMPTS"
echo "Retry interval: ${RETRY_INTERVAL}s"
echo "=========================================="

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt $attempt/$MAX_ATTEMPTS: Creating user sdg..."

    response_file=$(mktemp)

    http_status=$(curl -sS \
        --connect-timeout 10 \
        --max-time 60 \
        -o "$response_file" \
        -w "%{http_code}" \
        -X POST "${ELASTICSEARCH_URL}/_security/user/sdg" \
        -H "Content-Type: application/json" \
        -u "elastic:${ELASTICSEARCH_PASSWORD}" \
        -d '{
            "password": "changeme",
            "roles": ["superuser"],
            "full_name": "SDG User",
            "email": "sdg@elastic-pahlsoft.com"
        }')
    curl_status=$?

    if [ "$curl_status" -eq 0 ] && [[ "$http_status" =~ ^2 ]]; then
        echo "SUCCESS: User sdg created successfully (HTTP $http_status)"
        rm -f "$response_file"
        exit 0
    fi

    echo "FAILED: Attempt $attempt/$MAX_ATTEMPTS"
    echo "HTTP status: ${http_status:-000}"

    if [ "$curl_status" -ne 0 ]; then
        echo "curl error code: $curl_status"
    fi

    echo "Response:"
    cat "$response_file"
    echo

    rm -f "$response_file"

    if [ "$attempt" -lt "$MAX_ATTEMPTS" ]; then
        echo "Retrying in ${RETRY_INTERVAL} seconds..."
        sleep "$RETRY_INTERVAL"
    fi
done

echo "ERROR: Failed to create user sdg after $MAX_ATTEMPTS attempts."
exit 1