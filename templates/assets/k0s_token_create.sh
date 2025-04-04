#!/usr/bin/bash

set -e

source /etc/default/metadata

ORIGIN=$(hostname)

READY_NODES=$(k0s kubectl get nodes --no-headers | grep ' Ready' | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')

psql -U "$PGUSER" -d "$PGDB" -h "$PGCONTROLLER" -c "
    DELETE FROM k0s_tokens 
    WHERE role = 'controller' 
      AND cluster = '$CLUSTER' 
      AND origin NOT IN ($(echo $READY_NODES | sed "s/,/','/g" | sed "s/^/'/" | sed "s/$/'/"));
"

psql -U "$PGUSER" -d "$PGDB" -h "$PGCONTROLLER" -c "
    DELETE FROM k0s_tokens 
    WHERE role = 'controller' 
      AND cluster = '$CLUSTER' 
      AND origin = '$ORIGIN';
"

KTOKEN=$(k0s token create --role=controller)

if [[ -n "$KTOKEN" ]]; then
    if [[ -f /tmp/terminate-scheduled ]]; then
        exit 0
    fi
    psql -U "$PGUSER" -d "$PGDB" -h "$PGCONTROLLER" -c "
        INSERT INTO k0s_tokens (role, token, cluster, origin) 
        VALUES ('controller', '$KTOKEN', '$CLUSTER', '$ORIGIN');
    "
fi
