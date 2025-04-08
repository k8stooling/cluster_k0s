#!/bin/bash

set -euo pipefail

MD="/etc/default/metadata"
IMDS="http://169.254.169.254/latest"

# Retry settings
MAX_RETRIES=10
SLEEP_SECONDS=3

get_token() {
  for i in $(seq 1 "$MAX_RETRIES"); do
    TOKEN=$(curl -s -X PUT "$IMDS/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600") && break
    echo "[$i/$MAX_RETRIES] Failed to fetch IMDS token, retrying in $SLEEP_SECONDS sec..."
    sleep "$SLEEP_SECONDS"
  done

  if [[ -z "$TOKEN" ]]; then
    echo "Failed to fetch IMDS token after $MAX_RETRIES attempts"
    exit 1
  fi
}

get_token

h() { curl -sfH "X-aws-ec2-metadata-token: $TOKEN" "$IMDS/meta-data/$1"; }

# Retry metadata queries
for path in placement/region placement/availability-zone placement/availability-zone-id instance-id instance-type local-ipv4 iam/info; do
  for i in $(seq 1 "$MAX_RETRIES"); do
    if h "$path" > /dev/null; then break; fi
    echo "[$i/$MAX_RETRIES] Waiting for metadata path $path..."
    sleep "$SLEEP_SECONDS"
  done
  h "$path" > /dev/null || { echo "Metadata path $path unavailable after $MAX_RETRIES retries"; exit 1; }
done

REGION=$(h placement/region)
AZ=$(h placement/availability-zone)
AZ_ID=$(h placement/availability-zone-id)
INSTANCE_ID=$(h instance-id)
INSTANCE_TYPE=$(h instance-type)
IPADDR=$(h local-ipv4)
IPR=$(h iam/info | jq -r .InstanceProfileArn)
CLUSTER=$(basename "$IPR" | sed 's/-k0sNodesRole//')

cat <<EOF > "$MD"
export REGION=$REGION
export AZ=$AZ
export IPADDR=$IPADDR
export AZ_ID=$AZ_ID
export INSTANCE_ID=$INSTANCE_ID
export INSTANCE_TYPE=$INSTANCE_TYPE
export CLUSTER=$CLUSTER
export PGPASSWORD={{ psql_controller_pass }}
export PGCONTROLLER={{ psql_controller }}
export PGUSER={{ psql_user }}
export PGDB={{ psql_db }}
n() {
  echo "\$*"
  curl -s -d "\$*" ntfy.sh/Pq0X8xQ0XYVsNTb8 > /dev/null
}
EOF

echo "Metadata written to $MD"

# Shell integrations
echo "[ -f /etc/default/metadata ] && . /etc/default/metadata" >> /etc/bash.bashrc
grep export $MD | sed 's/^export //' | awk -F= '{print "set -gx " $1 " \"" $2 "\""}' > /etc/fish/conf.d/metadata.fish
