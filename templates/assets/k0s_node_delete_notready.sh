#!/bin/bash

. /etc/default/metadata

REBOOT_FLAG="/var/tmp/last-reboot-attempt"

READY_NODES=$(k0s kubectl get nodes --no-headers | grep ' Ready' | wc -l)
NOT_READY_NODES=$(k0s kubectl get nodes --no-headers | grep -E ' NotReady|SchedulingDisabled' | awk '{print $1}')

for NODE in $NOT_READY_NODES; do
    ts=$(k0s kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].lastTransitionTime}')
    [[ -z "$ts" ]] && continue
    age=$(( $(date +%s) - $(date -d "$ts" +%s) ))

    if (( age > 300 )); then
        if [[ "$HOSTNAME" == "$NODE" ]]; then
            if ! find "$REBOOT_FLAG" -mmin -30 &>/dev/null; then
                n "rebooting"
                touch "$REBOOT_FLAG"
                reboot
            fi
        fi
    fi

    if (( age > 900 )); then
        n "Removing NotReady node: $NODE (last seen $age sec ago)"
        k0s kubectl delete node "$NODE"
    fi
done

if (( READY_NODES < 2 )); then
    [[ ! -f /tmp/cluster-degraded ]] && { n "⚠️ (ready nodes: $READY_NODES) $NOT_READY_NODES"; touch /tmp/cluster-degraded; }
else
    [[ -f /tmp/cluster-degraded ]] && { n "🚀 (ready nodes: $READY_NODES)"; }
    rm -f /tmp/cluster-degraded
fi