#!/bin/bash

set -euo pipefail

source /etc/default/metadata

DELETE_ON_SHUTDOWN=$(k0s kubectl get configmap $[HOSTNAME}-node-shutdown-config -n kube-system -o=jsonpath='{.data.delete-on-shutdown}')

if [[ "$DELETE_ON_SHUTDOWN" == "true" ]]; then
    n "cleanup initiated"
    /usr/local/bin/k0s_node_unregister.sh || {
            n "Unregister script failed"
    }
    exit 0

fi
