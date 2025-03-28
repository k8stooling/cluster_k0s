#!/bin/bash

set -e

source /etc/default/metadata

HOSTNAME=$(hostname)

echo "topology.kubernetes.io/region=$REGION
topology.kubernetes.io/zone=$AZ
topology.kubernetes.io/zone-id=$AZ_ID
node.kubernetes.io/instance-type=$INSTANCE_TYPE
node.kubernetes.io/instance-id=$INSTANCE_ID
k0s.io/managed=true
k0s.io/cluster=$CLUSTER
k0s.io/origin=$HOSTNAME" | xargs -I {} k0s kubectl label node "$HOSTNAME" {} --overwrite

# Annotations
echo "k0s.io/managed=true
k0s.io/cluster=$CLUSTER
k0s.io/origin=$HOSTNAME" | xargs -I {} k0s kubectl annotate node "$HOSTNAME" {} --overwrite

echo "Node labeling and annotation complete."