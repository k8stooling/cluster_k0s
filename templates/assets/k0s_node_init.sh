#!/usr/bin/bash

source /etc/default/metadata

TOKEN_FROM_DB=$(psql -U $PGUSER -d $PGDB -h $PGCONTROLLER -t -A -c "SELECT token FROM k0s_tokens WHERE cluster = '$CLUSTER' ORDER BY created_at DESC LIMIT 1;")

/usr/local/bin/k0s_ca_restore.sh

if [[ -n "$TOKEN_FROM_DB" ]]; then
    echo "Token found in database"
    echo "$TOKEN_FROM_DB" > /etc/k0s/tokenfile
    k0s install controller --enable-worker --no-taints --force -c /etc/k0s/k0s.yaml --token-file /etc/k0s/tokenfile
else
    echo "No token in database, new standalone controller"
    k0s install controller --enable-worker --no-taints --force -c /etc/k0s/k0s.yaml
fi

k0s start