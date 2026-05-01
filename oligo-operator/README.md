# Oligo Operator Helm Chart Deployment

Deploys the Oligo Operator via ArgoCD with secrets managed by External Secrets Operator (ESO) backed by HashiCorp Vault KV v2.

## Architecture

```
Vault (KV v2)
  └── secret/oligo/imagepull    (username, password)
  └── secret/oligo/gateway      (apikey)
        │
        ▼
External Secrets Operator
  └── SecretStore (vault-backend)    ── authenticates via K8s SA ──▶ Vault
  └── ExternalSecret (imagepull)     ── creates ──▶ K8s Secret: oligoregcred (dockerconfigjson)
  └── ExternalSecret (apikey)        ── creates ──▶ K8s Secret: oligo-apikey (Opaque)
        │
        ▼
Oligo Operator Helm Chart
  └── Deployment consumes both secrets
```

## Directory Structure

```
oligo-operator/
├── Chart.yaml
├── values.yaml                         # Default chart values
├── operator-values.yaml                # Override values (no secrets — uses pre-existing K8s secrets)
├── sensor-values.yaml                  # Sensor configuration
├── native-values.yaml                  # Native mode configuration
├── argocd-app.yaml                     # Single-cluster ArgoCD Application
├── argocd-appset.yaml                  # Multi-cluster ArgoCD ApplicationSet
├── external-secrets/
│   ├── service-account.yaml            # Dedicated SA for ESO Vault auth (sync-wave: -3)
│   ├── secret-store.yaml               # Vault SecretStore connection (sync-wave: -2)
│   ├── external-secret-imagepull.yaml  # Image pull secret from Vault (sync-wave: -1)
│   └── external-secret-apikey.yaml     # API key secret from Vault (sync-wave: -1)
├── templates/
│   └── ...                             # Helm chart templates
└── crds/
    └── ...                             # CRDs
```

## Prerequisites

1. **Kubernetes cluster** with ArgoCD installed
2. **External Secrets Operator** installed in the cluster:
   ```bash
   helm repo add external-secrets https://charts.external-secrets.io
   helm install external-secrets external-secrets/external-secrets \
     -n external-secrets --create-namespace
   ```
3. **HashiCorp Vault** accessible from inside the cluster with KV v2 enabled

## Setup Steps

### 1. Enable Vault KV v2 Engine

```bash
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="<your-token>"

vault secrets enable -path=secret kv-v2
```

### 2. Store Secrets in Vault

```bash
vault kv put secret/oligo/imagepull \
  username="<docker-registry-username>" \
  password="<docker-registry-password>"

vault kv put secret/oligo/gateway \
  apikey="<oligo-api-key>"
```

### 3. Configure Vault Kubernetes Auth

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure it to reach the in-cluster K8s API
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# Create a read-only policy for Oligo secrets
vault policy write oligo-secrets - <<'EOF'
path "secret/data/oligo/*" {
  capabilities = ["read"]
}
path "secret/metadata/oligo/*" {
  capabilities = ["read", "list"]
}
EOF

# Create a role bound to the ESO service account
vault write auth/kubernetes/role/oligo-external-secrets \
  bound_service_account_names=oligo-eso-auth \
  bound_service_account_namespaces=oligo \
  policies=oligo-secrets \
  ttl=1h
```

### 4. Deploy with ArgoCD

**Single cluster:**
```bash
kubectl apply -f argocd-app.yaml
```

**Multi-cluster** (using ApplicationSet):
```bash
# Label each target cluster
kubectl label secret -n argocd \
  -l argocd.argoproj.io/secret-type=cluster \
  <cluster-secret-name> oligo-enabled=true

kubectl apply -f argocd-appset.yaml
```

## Sync Order (ArgoCD Sync Waves)

| Wave | Resource | Purpose |
|------|----------|---------|
| -3 | `ServiceAccount` (oligo-eso-auth) | SA for ESO to authenticate to Vault |
| -2 | `SecretStore` (vault-backend) | Vault connection configuration |
| -1 | `ExternalSecret` (imagepull + apikey) | Creates K8s secrets from Vault |
| 0 | Helm chart (oligo-operator) | Operator deployment consuming the secrets |

## Configuration

### operator-values.yaml

This file contains **non-sensitive** overrides only. Secrets are managed entirely through Vault + ESO.

Key settings:
- `imagePullSecret.create: false` — tells the chart to use a pre-existing secret
- `imagePullSecret.name: oligoregcred` — matches the ESO target secret name
- `controllerManager.gateway.apiKeySecretName: oligo-apikey` — matches the ESO target secret name

### Customizing Per Cluster

The `clusterName` is set via ArgoCD Helm parameters (not in values files). For multi-cluster,
the ApplicationSet templates it automatically from the ArgoCD cluster name.

## Troubleshooting

**SecretStore shows invalid / SA not found:**
- Verify the SA exists: `kubectl get sa oligo-eso-auth -n oligo`
- Check sync waves are being respected in ArgoCD

**Context deadline exceeded on Vault auth:**
- Vault can't reach the K8s API. Ensure `kubernetes_host` is set to `https://kubernetes.default.svc:443`
- Check: `vault read auth/kubernetes/config`

**403 on vault kv put:**
- KV v2 engine may not be enabled: `vault secrets list`
- Token policy may not cover the path: check with `vault token capabilities secret/data/oligo/imagepull`
