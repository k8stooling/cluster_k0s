#!/usr/bin/bash

source /etc/default/metadata

ORIGIN=$(hostname)

psql -U $PGUSER -d $PGDB -h $PGCONTROLLER -c "DELETE FROM k0s_tokens WHERE role = 'controller' AND cluster = '$CLUSTER' AND origin = '$ORIGIN';"

KTOKEN=$(k0s token create --role=controller)

if [[ "$KTOKEN" != "" ]]; then
    if [ -f /tmp/terminate-scheduled ]; then
    exit 0
    fi
    psql -U $PGUSER -d $PGDB -h $PGCONTROLLER -c "INSERT INTO k0s_tokens (role, token, cluster, origin) VALUES ('controller', '$KTOKEN', '$CLUSTER', '$ORIGIN');"
fi