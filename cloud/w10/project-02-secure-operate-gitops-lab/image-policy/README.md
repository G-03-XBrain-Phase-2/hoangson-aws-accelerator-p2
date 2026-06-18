# Image Signature Policy

This folder is intentionally disabled by default.

Enable it only after the app image has been built, scanned, pushed to GHCR and signed by Cosign.

Workflow:

1. Generate a Cosign key pair.
2. Store `COSIGN_PRIVATE_KEY` and `COSIGN_PASSWORD` in GitHub Secrets.
3. Commit only `cosign.pub`.
4. Copy `cluster-image-policy.yaml.example` to `cluster-image-policy.yaml`.
5. Paste the public key into the policy.
6. Copy `argocd/apps/image-policy.yaml.example` to `argocd/apps/image-policy.yaml`.
7. Commit and let ArgoCD sync.

Do not enable this policy before the app image is signed, or the cluster may reject your own workload.
