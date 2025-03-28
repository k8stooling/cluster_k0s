#!/bin/bash
# this script needs to be run only first time when cluster is created 
set -e

source /etc/default/metadata

CERTS_ARCHIVE="/tmp/k0s_certs.tar.gz"
CERTS_BASE64="/tmp/k0s_certs.b64"
CERTS_DIR="/var/lib/k0s/pki"
FILES_TO_BACKUP=("ca.crt" "ca.key" "sa.key" "sa.pub")

TMP_CERTS_DIR=$(mktemp -d)

for file in "${FILES_TO_BACKUP[@]}"; do
    cp "$CERTS_DIR/$file" "$TMP_CERTS_DIR/"
done

tar -czf "$CERTS_ARCHIVE" -C "$TMP_CERTS_DIR" .

base64 -w 0 "$CERTS_ARCHIVE" > "$CERTS_BASE64"

CERTS_DATA=$(cat "$CERTS_BASE64")

psql -U "$PGUSER" -d "$PGDB" -h "$PGCONTROLLER" <<EOF
INSERT INTO k0s_certs (cluster, certs) 
VALUES ('$CLUSTER', '$CERTS_DATA')
ON CONFLICT (cluster) DO UPDATE SET certs = EXCLUDED.certs, created_at = NOW();
EOF

echo "✅ k0s certificates backed up successfully!"