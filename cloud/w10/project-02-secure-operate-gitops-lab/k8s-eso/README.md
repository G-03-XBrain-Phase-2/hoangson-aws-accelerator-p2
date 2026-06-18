# External Secrets Operator Config

This folder contains GitOps-managed ESO config:

```text
secret-store.yaml
external-secret.yaml
```

Create AWS credentials as a runtime-only Kubernetes Secret before syncing `eso-config`:

```powershell
kubectl create secret generic aws-credentials -n demo `
  --from-literal=access-key-id=YOUR_AWS_ACCESS_KEY_ID `
  --from-literal=secret-access-key=YOUR_AWS_SECRET_ACCESS_KEY
```

Do not commit AWS credentials to Git.

Production EKS should use IRSA instead of static access keys. For this W10 lab, the static Kubernetes Secret pattern matches the mentor demo flow and keeps scope focused on ESO behavior.
