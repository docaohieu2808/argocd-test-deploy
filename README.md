# argocd-test-deploy

The sync target for the Argo CD lab: a small, hardened nginx Deployment (3 replicas) plus a ClusterIP Service in
`k8s/base/`, plus Kustomize overlays for staging and production in `k8s/overlays/`. It exists to practise the GitOps loop:

```
git commit -> GitHub -> Argo CD detects the diff -> syncs k8s/base -> cluster matches Git
```

## Files

| Path | What it is |
|---|---|
| `k8s/base/deployment.yaml` | `demo-web` Deployment: `nginxinc/nginx-unprivileged:1.30.6-alpine`, non-root, read-only root filesystem, probes, requests and limits |
| `k8s/base/service.yaml` | ClusterIP Service `demo-web` (port 80 to container port 8080) |
| `k8s/base/kustomization.yaml` | Lists the two manifests |
| `k8s/overlays/staging`, `k8s/overlays/production` | The base with 1 and 2 replicas |
| `argocd-application.yaml` | Standalone Argo CD Application for this repo (automated sync, prune, selfHeal) |

## Run it

You need a cluster with Argo CD (`kind create cluster`, or k3s; Argo CD v3.5.x):

```bash
kubectl create namespace argocd
kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.6/manifests/install.yaml
kubectl apply -n argocd -f argocd-application.yaml

kubectl -n argocd get application argocd-test-deploy        # Synced / Healthy
kubectl -n demo scale deployment demo-web --replicas=1      # drift: selfHeal puts it back to 3
```

Then edit `replicas` in `k8s/base/deployment.yaml`, commit and push: Argo CD picks it up within about 3 minutes (or
`argocd app sync argocd-test-deploy`). Revert the commit to practise a rollback.

## Part of the app-of-apps

[`argocd-apps`](https://github.com/docaohieu2808/argocd-apps) deploys this repo itself: its matrix ApplicationSet renders
`test-deploy-staging` and `test-deploy-production` from the two overlays, and its PR-preview
ApplicationSet creates a preview Application for every pull request on this repo that carries the `preview` label.
Applying that repo's `bootstrap/root-app.yaml` is therefore enough; this repo's own Application is for running it alone.

## What CI checks

`.github/workflows/ci.yml` runs on every push, pull request and weekly (Monday 02:47 UTC):

- `lint`: actionlint, shellcheck, yamllint, every action pinned to an existing commit SHA, `kubeconform -strict` against
  Kubernetes 1.37 and the Argo CD CRD schemas.
- `sync` (on the pinned Argo CD v3.5.6 and on the newest upstream release): starts a kind cluster, installs Argo CD,
  applies `argocd-application.yaml` pointed at this repository at the commit under test, waits until the app is Synced
  and Healthy, requests the Service from inside the cluster, then scales the Deployment by hand and requires selfHeal
  to restore 3 replicas.

## Limits

- Pull requests from forks cannot run `sync` (the fork's commit is not fetchable from this repository).
- It tests Argo CD against a public GitHub repository; private repositories, SSO and multi-cluster are in `argocd-apps`.
