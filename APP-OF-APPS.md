# App of apps test

The cluster-apps Application watches argocd/cluster and manages the library and
echo Application objects. Each child watches its own Helm chart and environment
values, and manages its own workloads. The parent lives in bootstrap/ outside
the directory it watches, so it cannot recursively manage itself.

## Start

Commit and push these files to main, then run on a machine with cluster access:

```bash
kubectl apply -f bootstrap/cluster.yaml
kubectl get applications -n argocd
```

Argo CD must already have read access to the Git repository. The default project
must permit this repository and the argocd, library, and echo namespaces.
Only trusted administrators should write to this repository because the parent
can create Applications.

The parent syncs automatically. It adopts the existing library Application by
name; no uninstall or database recreation is needed. The existing library
automated sync settings are preserved. Echo syncs automatically too.

Parent Synced status only confirms that child Application definitions match Git.
Check both children for Synced and Healthy before considering deployment complete.
The two children deploy independently; the parent imposes no dependency ordering.

## Test echo

```bash
kubectl -n echo rollout status deployment/echo --timeout=180s
kubectl -n echo port-forward svc/echo 8081:80
```

Leave port-forward running. In another terminal on that same machine:

```bash
curl http://127.0.0.1:8081
```

Expected: Hello from the cluster app of apps!
When port-forward runs on the controller, localhost refers to the controller.

Change message in environments/cluster/echo.yaml, commit, and push. Argo CD
updates the Deployment; the new pods return the new text. Reconnect port-forward
if its pod terminates during rollout. Changing replicaCount to 2 demonstrates
scaling without changing the library application.

## Removal and recovery

Parent pruning is disabled, so removing a child YAML from Git alone does not
delete that Application. No cascading deletion finalizers are added.
To remove echo, first remove its Application YAML from Git and push, then delete
the echo Application without cascading and delete only deployment/echo and
service/echo in namespace echo. Keep library and its PVC untouched.

The parent self-heals child Application definitions. Make persistent changes to
child sync policies in Git, rather than only in the Argo CD UI.

Reference: https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/
