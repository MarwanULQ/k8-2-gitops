# Monitoring apps

The parent app discovers monitoring, loki, and alloy Applications in argocd/cluster.
Each uses a pinned upstream Helm chart plus Git values from environments/cluster.
Argo CD multi-source Applications resolve the $values reference to this repository.

- monitoring: kube-prometheus-stack 69.8.2, Prometheus, Grafana, Alertmanager,
  kube-state-metrics, node exporter, and operator CRDs.
- loki: Loki chart 6.29.0 in single-binary mode with local-path storage.
- alloy: Alloy chart 0.12.6, one collector using the Kubernetes API for pod logs.

These explicit versions were rendered during development; upgrades require
reviewing upstream changes and rendering again. They are not floating latest.

Before syncing, bootstrap monitoring/grafana-admin with admin-user and
admin-password keys through the k8-2 Ansible deployment. Existing library
Secrets and local-path provisioner are also required.

Grafana reads Loki at http://loki-gateway.monitoring.svc.cluster.local.
Alloy sends logs to that gateway. Log labels include namespace, pod, container.
Try {namespace="library"} in Grafana Explore after generating application traffic.

NodePorts: Grafana 30300, Prometheus 30090, Alertmanager 30903,
Loki 30310, Alloy 31235. Terraform in k8-2 restricts these to admin_cidr.
The Argo UI uses HTTPS 30443.

The charts reconcile independently. Alloy retries while Loki starts. Monitoring
uses server-side apply for large operator CRDs. Control-plane etcd, scheduler,
and controller-manager scraping are disabled because default kubeadm endpoints
are not exposed for remote scraping.

Library migration now uses a Sync hook at wave 1, after PostgreSQL at wave 0
and before the Flask Deployment at wave 2.

Check child Applications, not just the parent:

```bash
kubectl get applications -n argocd
kubectl get pods,pvc -n monitoring
```

Persistent local-path storage survives pod restarts but not node destruction.
This lab does not configure HA or backups.
