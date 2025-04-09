#!/bin/bash

. /etc/default/metadata

READY_NODES=$(k0s kubectl get nodes --no-headers | grep ' Ready' | wc -l)
NOT_READY_NODES=$(k0s kubectl get nodes --no-headers | grep -E ' NotReady|SchedulingDisabled' | awk '{print $1}')

now=$(date +%s)

for NODE in $NOT_READY_NODES; do
    ts=$(k0s kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].lastTransitionTime}')
    [[ -z "$ts" ]] && continue  # skip if node has no Ready condition
    age=$(( now - $(date -d "$ts" +%s) ))

    if (( age > 300 )); then
        n "NotReady 5m threshold approaching: $NODE (last seen $age sec ago)"
        [[ "$HOSTNAME" == "$NODE" ]] && { n "Rebooting self"; reboot; }
    fi

    if (( age > 900 )); then
        n "Removing NotReady node: $NODE (last seen $age sec ago)"
        k0s kubectl delete node "$NODE"
    fi
done

if (( READY_NODES < 2 )); then
    [[ ! -f /tmp/cluster-degraded ]] && { n "Cluster degraded: $NOT_READY_NODES"; touch /tmp/cluster-degraded; }
else
    rm -f /tmp/cluster-degraded
fi