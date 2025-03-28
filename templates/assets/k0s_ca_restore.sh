#!/bin/bash
set -e

source /etc/default/metadata

CERTS_ARCHIVE="/tmp/k0s_certs.tar.gz"
CERTS_BASE64="/tmp/k0s_certs.b64"
PKIDIR="/var/lib/k0s/pki"

psql -U "$PGUSER" -d "$PGDB" -h "$PGCONTROLLER" -t -A -c \
    "SELECT certs FROM k0s_certs LIMIT 1" > "$CERTS_BASE64"

base64 -d "$CERTS_BASE64" > "$CERTS_ARCHIVE"

mkdir -p $PKIDIR
tar -xzf "$CERTS_ARCHIVE" -C $PKIDIR