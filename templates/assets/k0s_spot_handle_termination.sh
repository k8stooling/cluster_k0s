#!/bin/bash

set -euo pipefail

source /etc/default/metadata

TOKEN=""
HTTP_CODE="503"
ORIGIN=$(hostname)
METADATA_URL="http://169.254.169.254/latest/meta-data/spot/instance-action"
TOKEN_URL="http://169.254.169.254/latest/api/token"

while true; do
    
    if [[ -z "$TOKEN" ]] ; then
        echo "Requesting a new IMDSv2 token..."
        TOKEN=$(curl -s -X PUT "$TOKEN_URL" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600")
    fi

    HTTP_CODE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -o /dev/null -w "%{http_code}" -s "$METADATA_URL")

    if [[ "$HTTP_CODE" != "404" ]] && [[ ! -f /tmp/terminate-scheduled ]]; then
        echo "Spot termination notice received!"

        k0s kubectl drain "$ORIGIN" --ignore-daemonsets --delete-emptydir-data || true

        sleep 40

        if k0s kubectl delete node "$ORIGIN"; then
            echo "Node $ORIGIN deleted successfully."

            touch /tmp/terminate-scheduled

            psql -U "$PGUSER" -d "$PGDB" -h "$PGCONTROLLER" -c \
                "DELETE FROM k0s_tokens WHERE role = 'controller' AND cluster = '$CLUSTER' AND origin = '$ORIGIN';"

            /usr/local/bin/update_dns.sh || true

            exit 0
        else
            echo "Warning: node delete failed, retrying later..."
        fi
    fi

    if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "404" ]]; then
        echo "Unexpected HTTP code: $HTTP_CODE. Clearing token."
        TOKEN=""
    fi

    sleep 5
done
