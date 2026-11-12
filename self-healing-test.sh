#!/bin/bash
# K3s self-healing test:
#   1. Deploy Nginx with 3 replicas
#   2. Check the pods
#   3. Delete some pods to simulate a failure
#   4. Watch Kubernetes recreate them and measure the recovery time
# Everything is shown on screen and saved to a results file.
#
# Usage: ./self-healing-test.sh [pods_to_delete]    (default: 2)

set -o pipefail                 # a failing command is not hidden by "| tee"
cd "$(dirname "$0")"            # run from the script folder so the YAML is found
export KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}   # default K3s config

TO_DELETE=${1:-2}               # how many pods to delete
REPLICAS=3                      # must match "replicas" in nginx-deployment.yaml
TIMEOUT=120                     # give up if recovery takes longer than this (seconds)
OUT="results-delete-$TO_DELETE.txt"

# Print text on screen and save it to the results file
log() { echo "$@" | tee -a "$OUT"; }

# Run a command, show its output and save it to the results file
run() { "$@" 2>&1 | tee -a "$OUT"; }

# Count pods that are ready (1/1 Running). Pods being deleted show
# "Terminating" and new ones "ContainerCreating", so they are not counted.
ready_pods() { kubectl get pods -l app=nginx --no-headers | grep -cE '1/1 +Running'; }

# Stop early if the cluster can't be reached
if ! kubectl get nodes >/dev/null 2>&1; then
  echo "Error: cannot reach the K3s cluster. Is K3s installed and running?"
  exit 1
fi

: > "$OUT"                      # start with an empty results file
log "K3s self-healing test - $(date '+%Y-%m-%d %H:%M:%S')"
run kubectl get nodes

log ""
log "=== STEP 1: Deploy (replicas: $REPLICAS) ==="
run kubectl apply -f nginx-deployment.yaml || { log "Error: deploy failed."; exit 1; }
run kubectl rollout status deployment/nginx-demo --timeout="${TIMEOUT}s" || { log "Error: deployment not ready."; exit 1; }

# Wait until only the 3 ready pods exist (no leftovers from an earlier run)
SECONDS=0
while [ "$(kubectl get pods -l app=nginx --no-headers | wc -l)" -ne "$REPLICAS" ] || [ "$(ready_pods)" -ne "$REPLICAS" ]; do
  if [ "$SECONDS" -ge "$TIMEOUT" ]; then
    log "Error: old pods are still around after $TIMEOUT seconds."
    exit 1
  fi
  sleep 1
done

log ""
log "=== STEP 2: Check pods ==="
run kubectl get pods -l app=nginx -o wide

log ""
log "=== STEP 3: Delete $TO_DELETE pod(s) ==="
# Pick the first N ready pods
PODS=$(kubectl get pods -l app=nginx --no-headers | awk -v n="$TO_DELETE" '/1\/1 +Running/ && c < n { print "pod/" $1; c++ }')
START=$(date +%s.%N)            # start the timer
run kubectl delete $PODS --wait=false   # don't wait, so we only time the recovery

log ""
log "=== STEP 4: Kubernetes reaction ==="
run kubectl get pods -l app=nginx   # right after the failure: old pods Terminating, new ones being created

# Wait until all replicas are ready again (check every 0.5 s)
SECONDS=0
while [ "$(ready_pods)" -lt "$REPLICAS" ]; do
  if [ "$SECONDS" -ge "$TIMEOUT" ]; then
    log "Error: pods did not recover within $TIMEOUT seconds."
    exit 1
  fi
  sleep 0.5
done
END=$(date +%s.%N)              # stop the timer
TIME=$(awk "BEGIN { printf \"%.1f\", $END - $START }")   # bash can't do decimals, awk can

log ""
log "=== FINAL RESULT ==="
run kubectl get pods -l app=nginx
log "Deleted pods: $(echo $PODS)"
log "Time until $REPLICAS pods were ready again: $TIME seconds"

log ""
log "=== EVENTS: who created the new pods ==="
# The ReplicaSet events show it created the replacement pods by itself
run bash -c "kubectl get events --field-selector reason=SuccessfulCreate --sort-by=.lastTimestamp | tail -n $TO_DELETE"
