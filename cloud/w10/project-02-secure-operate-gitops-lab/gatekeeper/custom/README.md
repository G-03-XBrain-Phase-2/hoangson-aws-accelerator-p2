# Optional Custom Gatekeeper Policy

The owner-label policy is kept in this folder as an optional extension.

It is not synced by the default ArgoCD app path because the mentor scope requires four core policies:

```text
1. disallow latest image tag
2. require resources limits
3. disallow root user
4. disallow hostNetwork
```

Enable the owner-label policy only if you want an extra challenge after the required demo passes.
