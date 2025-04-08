#!/bin/bash

set -euo pipefail

source /etc/default/metadata

TOKEN=""
METADATA_URL="http://169.254.169.254/latest/meta-data/spot/instance-action"
TOKEN_URL="http://169.254.169.254/latest/api/token"

while true; do
    if [[ -z "$TOKEN" ]]; then
        echo "Requesting new IMDSv2 token..."
        TOKEN=$(curl -s -X PUT "$TOKEN_URL" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600") || {
            echo "Failed to fetch token"
            sleep 5
            continue
        }
    fi

    HTTP_CODE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -o /dev/null -w "%{http_code}" -s "$METADATA_URL")

    if [[ "$HTTP_CODE" == "404" ]]; then
        sleep 5
        continue
    fi

    if [[ "$HTTP_CODE" == "200" && ! -f /tmp/terminate-scheduled ]]; then
        n "termination notice received!"

        k0s kubectl drain "$HOSTNAME" --ignore-daemonsets --delete-emptydir-data || true
        sleep 40

        if k0s kubectl delete node "$HOSTNAME"; then
            touch /tmp/terminate-scheduled

            psql -U "$PGUSER" -d "$PGDB" -h "$PGCONTROLLER" -c \
                "DELETE FROM k0s_tokens WHERE role = 'controller' AND cluster = '$CLUSTER' AND origin = '$HOSTNAME';"

            /usr/local/bin/k0s_dns_update.sh || true
            n "$HOSTNAME is shut down gracefully."
            exit 0
        else
            n "Node deletion failed; will retry."
        fi
    elif [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "404" ]]; then
        echo "Unexpected $HTTP_CODE — new token."
        TOKEN=""
    fi

    sleep 5
done
