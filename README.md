# K3s Pod Self-Healing

Deploys Nginx with 3 replicas on K3s, deletes 1 or 2 pods and measures how long Kubernetes takes to have 3 ready pods again.

## Requirements

Linux or WSL with K3s:

```bash
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -
```

## Run

On Windows, open WSL in this folder (in PowerShell):

```powershell
cd k3s-pod-self-healing
wsl
```

Then:

```bash
bash self-healing-test.sh 1
bash self-healing-test.sh 2
```

The number is how many pods to delete (1, 2 or 3). Each run saves its output to `results-delete-<N>.txt`.

To watch the recovery live (for screenshots), run `kubectl get pods -l app=nginx -w` in a second WSL terminal before the test.

## Results (K3s v1.36.5, WSL2, one node)

| Pods deleted | Recovery time |
|---|---|
| 1 | 1.8 s |
| 2 | 2.5 s |

Precision is about 0.5 s. The time changes a little between runs (between 1.7 and 3.4 s in our tests). This shows pod regeneration (done by the ReplicaSet), not node regeneration, which needs more than one node.
