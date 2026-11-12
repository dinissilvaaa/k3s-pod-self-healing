#!/bin/bash
N=${1:-2}                                        # number of pods to delete (default 2)
if [[ ! "$N" =~ ^[1-3]$ ]]; then                 # only 1, 2 or 3 make sense, because there are 3 pods
  echo "Error: the number of pods to delete must be 1, 2 or 3 (the Deployment only has 3 pods)."  # explain the problem
  exit 1                                         # stop without touching the cluster
fi                                               # end of the check
exec > >(tee "results-delete-$N.txt") 2>&1       # from here on, show everything on screen and save it to the results file

ready_pods() { kubectl get pods -l app=nginx | grep '1/1 *Running'; }  # list only ready pods (Terminating and ContainerCreating are left out)

echo "=== STEP 1: Deploy ==="                      # title of step 1
kubectl apply -f nginx-deployment.yaml           # send the desired state (3 replicas) to the cluster
kubectl rollout status deployment/nginx-demo || exit 1  # wait until the 3 pods are ready, stop if it fails

echo -e "\n=== STEP 2: Check pods ==="            # title of step 2 (\n adds a blank line before it)
kubectl get pods -l app=nginx                    # show the pods: 3 should be 1/1 Running

echo -e "\n=== STEP 3: Delete $N pod(s) ==="     # title of step 3
PODS=$(ready_pods | head -n "$N" | awk '{print $1}')  # names of the first N ready pods
START=$(date +%s.%N)                             # start the timer (seconds with decimals)
kubectl delete pod $PODS --wait=false            # simulate the failure; don't wait, so only the recovery is timed

echo -e "\n=== STEP 4: Kubernetes reaction ==="  # title of step 4
kubectl get pods -l app=nginx                    # right after the failure: old pods Terminating, new ones ContainerCreating
while [ "$(ready_pods | wc -l)" -lt 3 ]; do      # repeat while fewer than 3 pods are ready
  sleep 0.5                                      # check again every 0.5 seconds
done                                             # end of the loop: 3 pods are ready again
TIME=$(awk "BEGIN {printf \"%.1f\", $(date +%s.%N) - $START}")  # stop the timer: now minus start, 1 decimal (bash can't do decimals)

echo -e "\n=== FINAL RESULT ==="                 # title of the result
kubectl get pods -l app=nginx                    # 3 pods Running again, the new ones with new names and a low AGE
echo "Recovery time: $TIME seconds"              # print the measured recovery time

echo -e "\n=== WHO CONTROLS THE PODS ==="        # title of the last section
kubectl get pods -l app=nginx -o custom-columns=POD:.metadata.name,CONTROLLED_BY:.metadata.ownerReferences[0].kind  # owner of each pod: the ReplicaSet, which recreated the deleted ones
