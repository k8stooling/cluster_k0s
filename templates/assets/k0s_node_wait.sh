#!/bin/bash

source /etc/default/metadata

HOSTNAME=$(hostname)
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
    echo "Error: Kubeconfig did not appear after $MAX_RETRIES attempts."
    curl -s -d "$(hostname) failed to init (missing kubeconfig)" ntfy.sh/Pq0X8xQ0XYVsNTb8
    exit 1
fi

# Wait for node to appear in Kubernetes
echo "Waiting for node $HOSTNAME to be registered in Kubernetes..."
for ((i=1; i<=MAX_RETRIES; i++)); do
    echo "Attempt $i: Checking node registration..."
    
    NODE_EXISTS=$(k0s kubectl get node "$HOSTNAME" --no-headers 2>/dev/null || echo "")

    if [[ -n "$NODE_EXISTS" ]]; then
        echo "Node $HOSTNAME is registered!"
        curl -s -d "$(hostname) is on" ntfy.sh/Pq0X8xQ0XYVsNTb8
        exit 0
    fi
    
    echo "Node $HOSTNAME is not yet registered. Retrying in $RETRY_INTERVAL seconds..."
    sleep "$RETRY_INTERVAL"
done

echo "Error: Node $HOSTNAME was not registered after $MAX_RETRIES attempts."
curl -s -d "$(hostname) failed to init (not registered)" ntfy.sh/Pq0X8xQ0XYVsNTb8
exit 1
