#!/bin/bash

source /etc/default/metadata

NODE=$(hostname)

TOKEN=""

while true; do
    
    if [[ -z "$TOKEN" ]]; then
        TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600" -s)
        echo  "New token received: $TOKEN"
    fi

    RESPONSE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s -w "%{http_code}" -o /tmp/spot-action.json http://169.254.169.254/latest/meta-data/spot/instance-action)
    HTTP_CODE=${RESPONSE: -3}

    if [[ "$HTTP_CODE" == "200" ]]; then
        ACTION=$(jq -r .action /tmp/spot-action.json)

        curl -d "$NODE is over" ntfy.sh/Pq0X8xQ0XYVsNTb8

        k0s kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data
        
        sleep 40

        k0s kubectl delete node "$NODE"

        psql -U "$PGUSER" -d "$PGDB" -h "$PGCONTROLLER" -c "DELETE FROM k0s_tokens WHERE role = 'controller' AND cluster = '$CLUSTER' AND origin = '$NODE';"

        /usr/local/bin/k0s_dns_update.py

        exit 0
    fi

    if [[ "$HTTP_CODE" != "404" && "$HTTP_CODE" != "200" ]]; then
        TOKEN=""
    fi

    sleep 5
done