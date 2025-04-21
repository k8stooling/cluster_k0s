#!/bin/bash

set -euo pipefail

source /etc/default/metadata

k0s kubectl drain "$HOSTNAME" --ignore-daemonsets --delete-emptydir-data || true
sleep 40

DELETE_OUTPUT=$(k0s kubectl delete node "$HOSTNAME" 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    touch /tmp/terminate-scheduled

    psql -U "$PGUSER" -d "$PGDB" -h "$PGCONTROLLER" -c \
        "DELETE FROM k0s_tokens WHERE role = 'controller' AND cluster = '$CLUSTER' AND origin = '$HOSTNAME';"

    /usr/local/bin/k0s_dns_update.sh || true

    k0s kubectl delete configmap "${HOSTNAME}-node-shutdown-config" -n kube-system 2>/dev/null || true

    n "down"
    exit 0
else
    n "Node deletion failed with exit code $EXIT_CODE: $DELETE_OUTPUT"
    exit 1
fi
