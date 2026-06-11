# argocd-test-deploy

ArgoCD sync target for lab practice. A minimal nginx Deployment (3 replicas) + ClusterIP Service used to demonstrate the ArgoCD commit-to-sync loop.

## Purpose

This repo is the **sync target** when bootstrapping ArgoCD on a local K3s cluster:

```
git commit → GitHub → ArgoCD detects diff → syncs k8s/ → cluster state updated
```

Useful for practising:
- App-of-apps bootstrap (point `argocd-apps` root-app here)
- Watching automated sync + selfHeal in real time
- Triggering rollbacks by reverting a commit

## Files

| File | Description |
|---|---|
| `k8s/deployment.yaml` | `apps/v1` Deployment (nginx:alpine, 3 replicas, resource requests) + ClusterIP Service |

## Quick demo

```bash
# 1. Bootstrap ArgoCD on K3s (see container-orchestration repo)
# 2. Create an Application pointing to this repo
kubectl apply -n argocd -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-test-deploy
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/docaohieu2808/argocd-test-deploy.git
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# 3. Edit replicas in k8s/deployment.yaml, commit + push
# 4. Watch ArgoCD sync within ~3 minutes (or trigger manually)
argocd app sync argocd-test-deploy
argocd app get argocd-test-deploy
```

## Relationship to other repos

- `argocd-apps` — control plane that can manage this repo via an ApplicationSet or direct Application
- `container-orchestration` — K3s install scripts to set up the target cluster
