#!/bin/bash

READY_NODES=$(k0s kubectl get nodes --no-headers | grep ' Ready' | wc -l)
NOT_READY_NODES=$(k0s kubectl get nodes --no-headers | grep -E ' NotReady|SchedulingDisabled' | awk '{print $1}')

for NODE in $NOT_READY_NODES; do
    LAST_HEARTBEAT=$(k0s kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].lastTransitionTime}')
    LAST_HEARTBEAT_SECONDS=$(date -d "$LAST_HEARTBEAT" +%s)
    CURRENT_TIME_SECONDS=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME_SECONDS - LAST_HEARTBEAT_SECONDS))

    if [[ "$TIME_DIFF" -gt 600 && "$READY_NODES" -ge 2 ]]; then
        echo "Removing NotReady node: $NODE (last seen $TIME_DIFF seconds ago)"
        k0s kubectl delete node "$NODE"        
    fi
done
