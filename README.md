# K3s Self-Healing

Cloud Computing project (topic 11): show that Kubernetes (K3s) brings pods back automatically after a failure.

We deploy Nginx with 3 replicas, delete 1 or 2 pods on purpose, and measure how long Kubernetes takes to have 3 ready pods again.

## Files

| File | What it does |
|---|---|
| `nginx-deployment.yaml` | Deployment with the desired state: 3 Nginx pods |
| `self-healing-test.sh` | Deploys, checks the pods, deletes some, waits for recovery and measures the time |
| `results-delete-1.txt` | Output of a run deleting 1 pod |
| `results-delete-2.txt` | Output of a run deleting 2 pods |

## Requirements

- Linux (Ubuntu in a VM or WSL2 works)
- K3s installed:

```bash
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -
kubectl get nodes    # the node should be Ready
```

## How to run

```bash
chmod +x self-healing-test.sh
./self-healing-test.sh 1    # delete 1 pod
./self-healing-test.sh 2    # delete 2 pods (default)
```

Each run saves its output to `results-delete-<N>.txt`.

To watch the recovery live, run this in a second terminal before starting the test:

```bash
kubectl get pods -l app=nginx -w
```

To remove everything at the end:

```bash
kubectl delete -f nginx-deployment.yaml
```

## How it works

1. **Deploy**: `kubectl apply` sends the desired state (3 replicas) to the cluster.
2. **Check**: `kubectl get pods` shows 3 pods `1/1 Running`.
3. **Failure**: `kubectl delete pod` removes 1 or 2 pods.
4. **Recovery**: the ReplicaSet sees fewer pods than wanted and creates new ones. The script checks every 0.5 s until 3 pods are ready again and prints the time.

The readiness probe makes sure a pod only counts as ready when Nginx actually answers on port 80. The liveness probe restarts the container if Nginx stops answering.

## Results (K3s v1.36.5 on WSL2, single node)

| Pods deleted | Recovery time |
|---|---|
| 1 | 2.7 s |
| 2 | 2.1 s |

The time includes the readiness check and has a precision of about 0.5 s.

## Note: pods vs nodes

This test shows **pod** regeneration, done by the ReplicaSet. Recovering from a **node** failure (moving pods to another machine) needs a cluster with more than one node, which this single-node setup does not have.
