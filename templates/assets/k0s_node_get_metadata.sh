#!/bin/bash

set -e

METADATA_FILE="/etc/default/metadata"

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600" -s)
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region)
AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
AZ_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone-id)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_TYPE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-type)
IPADDR=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4)
IPR=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/iam/info | jq .InstanceProfileArn -r)
CLUSTER=$(basename $IPR | sed 's/-k0sNodesRole//')

cat <<EOF > $METADATA_FILE
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
EOF

echo "Metadata written to $METADATA_FILE"

echo "[ -f /etc/default/metadata ] && . /etc/default/metadata" >> /etc/bash.bashrc
cat /etc/default/metadata | sed 's/^export //' |  awk -F= '{print "set -gx " $1 " \"" $2 "\""}' > /etc/fish/conf.d/metadata.fish