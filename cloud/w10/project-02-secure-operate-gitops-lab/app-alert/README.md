# Alertmanager Email Secret

`email-secret.yaml.example` is a template only.

Create the real runtime secret locally:

```powershell
Copy-Item app-alert/email-secret.yaml.example app-alert/email-secret.yaml
notepad app-alert/email-secret.yaml
kubectl apply -f app-alert/email-secret.yaml
```

`email-secret.yaml` is ignored by Git and must not be committed.

Verify:

```powershell
kubectl get secret alertmanager-email -n monitoring
kubectl exec -n monitoring statefulset/alertmanager-kube-prometheus-stack-alertmanager -- ls /etc/alertmanager/secrets/alertmanager-email/
```
