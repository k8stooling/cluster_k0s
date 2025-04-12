#!/usr/bin/bash

cd /var/tmp || exit 1

for script in *.b64; do
    name="${script%.b64}"
    base64 -d "$script" | xz -d > "/usr/local/bin/$name"
    chmod 755 "/usr/local/bin/$name"
done