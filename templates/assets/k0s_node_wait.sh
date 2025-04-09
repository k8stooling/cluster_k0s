#!/bin/bash

source /etc/default/metadata

MAX_RETRIES=20
RETRY_INTERVAL=20
KUBECONFIG_PATH="/var/lib/k0s/pki/admin.conf"

echo "Waiting for k0s to be fully initialized on node $HOSTNAME..."

# Wait for kubeconfig to be available
for ((i=1; i<=MAX_RETRIES; i++)); do
    echo "Attempt $i: Checking if kubeconfig exists..."
    if [[ -f "$KUBECONFIG_PATH" ]]; then
        echo "Kubeconfig found!"
        break
    fi
    echo "Kubeconfig is missing. Retrying in $RETRY_INTERVAL seconds..."
    sleep "$RETRY_INTERVAL"
done

if [[ ! -f "$KUBECONFIG_PATH" ]]; then
    n "failed (missing kubeconfig)"
    exit 1
fi

# Wait for node to appear in Kubernetes
echo "Waiting for node $HOSTNAME to be registered in Kubernetes..."
for ((i=1; i<=MAX_RETRIES; i++)); do
    echo "Attempt $i: Checking node registration..."
    
    NODE_EXISTS=$(k0s kubectl get node "$HOSTNAME" --no-headers 2>/dev/null || echo "")

    if [[ -n "$NODE_EXISTS" ]]; then
        echo "Node $HOSTNAME is registered!"
        n "on"
        exit 0
    fi
    
    echo "Node $HOSTNAME is not yet registered. Retrying in $RETRY_INTERVAL seconds..."
    sleep "$RETRY_INTERVAL"
done

n "Error: not registered after $MAX_RETRIES attempts."
exit 1
