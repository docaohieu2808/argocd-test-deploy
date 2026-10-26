#!/usr/bin/env bash
# Prove the commit -> sync -> selfHeal loop the README teaches, on the running cluster.
set -euo pipefail

ns=demo
want=$(kubectl -n "$ns" get deployment demo-web -o jsonpath='{.spec.replicas}')
[ "$want" = 3 ] || { echo "FAIL expected 3 replicas from Git, got $want" >&2; exit 1; }
kubectl -n "$ns" rollout status deployment/demo-web --timeout=180s

# The service answers (from inside the cluster, through the Service).
kubectl -n "$ns" run curl --image=curlimages/curl:8.21.0 --restart=Never --rm -i --quiet \
  --command -- curl -fsS --max-time 10 http://demo-web.demo.svc.cluster.local/ | grep -q 'Welcome to nginx'
echo "ok   service answers"

# Drift: scale by hand; selfHeal must put it back to what Git says.
kubectl -n "$ns" scale deployment/demo-web --replicas=1
for _ in $(seq 1 60); do
  now=$(kubectl -n "$ns" get deployment demo-web -o jsonpath='{.spec.replicas}')
  [ "$now" = 3 ] && { echo "ok   selfHeal restored 3 replicas"; exit 0; }
  sleep 3
done
echo "FAIL selfHeal did not restore replicas (now $now)" >&2
exit 1
