# Library GitOps

This repository contains deployment configuration only. Application source,
Docker builds, Terraform, and cluster provisioning remain in k8-2.

## Contents

- apps/library/Chart.yaml: chart metadata.
- apps/library/values.yaml: non-secret defaults, replicas, storage, and ports.
- environments/cluster/library.yaml: deployed application image.
- apps/library/templates/: Kubernetes workloads, services, and configuration.
- argocd/cluster/library.yaml: Argo CD source and destination.

Argo CD renders Helm templates; it does not run helm upgrade or create a Helm
release. Namespace is library. Resource names and PostgreSQL claim identity
data-postgres-0 are preserved.

## Before first sync

1. Back up the existing database. Do not uninstall Helm or delete the namespace.
2. Stop active Webapp workflows and disable the old direct Ansible deployment
   step in k8-2 before enabling Argo management. The original repo has not been
   modified by this extraction.
3. Confirm the existing library-secrets Secret has POSTGRES_PASSWORD and
   SECRET_KEY, and ghcr-pull-secret contains valid GHCR credentials. These Secrets
   are deliberately external to this chart. Never commit credentials.
4. Confirm local-path StorageClass and data-postgres-0 PVC exist.
5. Read the deployed image:

   kubectl -n library get deployment flask-webapp -o jsonpath='{.spec.template.spec.containers[*].image}'

6. Replace REPLACE_WITH_DEPLOYED_SHA in environments/cluster/library.yaml
   with the known, published image tag. The placeholder deliberately prevents
   accidentally selecting an unbuilt commit.
7. Publish this repository when ready. Update repoURL in argocd/cluster/library.yaml
   to the actual Git URL. Configure private repository access in Argo CD.
8. Commit and push configuration, then apply:

   kubectl apply -f argocd/cluster/library.yaml
   argocd app diff library
   argocd app sync library
   argocd app wait library --health --sync --timeout 300

First sync is manual. Automatic pruning and self-healing are not enabled.
No Application deletion finalizer is configured.

## Deployment order

Wave 0 applies ConfigMap, Services, and PostgreSQL. Wave 2 rolls out Flask.
The current migration Job retains its Helm post-install/post-upgrade hook;
Argo CD maps that to PostSync, so migrations run after resources are healthy.
Migration and Flask use the same pinned image. This restructure preserves
that behavior; database-dependent readiness checks would require revisiting
the migration ordering.

The existing Secrets must be present before sync. PostgreSQL uses the existing
password; changing a Secret does not rotate a password in an existing database.
The database username and name remain library because connection URLs use them.

## Future releases

Build and push images from the application repository, then commit the immutable
image tag to environments/cluster/library.yaml here. Argo CD reads that commit and
deploys it on sync. This local extraction does not yet wire cross-repository CI.
Do not run the old Helm deployment pipeline alongside Argo CD.

## Validation

helm lint apps/library --set-string image=ghcr.io/example/library:test
helm template library apps/library --namespace library --set-string image=ghcr.io/example/library:test

## Recovery

Revert the Git image/configuration change and sync again. Database migrations
are not automatically rolled back. Keep migrations compatible with old app
versions. To return control to the original Helm pipeline, first stop Argo
management without deleting workloads, and reconcile Helm's stale release state
against the live cluster before deployment. Never helm uninstall as a handoff.

Local-path storage is tied to its node; this chart does not add database backups
or high availability. NodePorts remain 30080 (web) and 30432 (database).

## Adding another service

Use one chart, environment values file, and Argo CD Application per service:

```text
apps/
  library/                 # Current Flask + PostgreSQL deployment unit
environments/
  cluster/
    library.yaml           # Image and environment overrides
argocd/
  cluster/
    library.yaml           # Application pointing to chart and values
```

For a future service named notifications, add apps/notifications/ with its own
Chart.yaml, values.yaml, and templates. Add environments/cluster/notifications.yaml
and argocd/cluster/notifications.yaml. Set the new Application name, chart path,
release name, and destination namespace explicitly. The values file path is
relative to the chart: ../../environments/cluster/notifications.yaml.

Use distinct workload names, selectors, and NodePorts for each service. Do not
copy the library database or fixed resource names into another chart unchanged.
Keep library's database in its chart until there is an actual need to separate
its ownership. This directory layout does not split application code into services.

Apply individual Applications, or register all Applications in this environment:

```bash
kubectl apply -f argocd/cluster/
```

## Updating an existing Application after this restructure

Push the path changes before applying argocd/cluster/library.yaml. The Application
keeps its existing name, namespace, release name, and destination; only source
paths change. Refresh and inspect its diff before syncing. Do not delete the
Application, release, namespace, or PVC during this directory move.
