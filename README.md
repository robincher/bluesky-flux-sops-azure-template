# Introduction

Boilerplate to set-up Flux v2 and Mozilla SOPs powered by Azure services

Caveat : This is only a boilerplate to show how Flux can be structured with both configurations and Secrets. You can restructure your project and folder structure based on your own requirements or preferences.

## Bootstrapping AKS with SOPS

### Create Pod Identity

AAD Pod Identity enables Kubernetes applications to access Azure resources securely with Azure Active Directory. It will allow us to bind a Managed Identity to Flux's kustomize-controller.

```
# ./clusters/play/flux-sysetm/aad-pod-identity.yaml

apiVersion: v1
kind: Namespace
metadata:
  name: aad-pod-identity
---
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: HelmRepository
metadata:
  name: aad-pod-identity
  namespace: aad-pod-identity
spec:
  url: https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts
  interval: 10m
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: aad-pod-identity
  namespace: aad-pod-identity
spec:
  interval: 5m
  chart:
    spec:
      chart: aad-pod-identity
      version: 4.1.5
      sourceRef:
        kind: HelmRepository
        name: aad-pod-identity
        namespace: aad-pod-identity
      interval: 1m


```

### Configure in-cluster secrets decryption

Bind a pre-created managed identity previously to the kustomize-controller.

Next, we need to patch the kustomize-controller with the AzureIdentity by providing the specific label shown below:


```
cat > ./clusters/play/sops-kustomize-patch.yaml 
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kustomize-controller
  namespace: flux-system
spec:
  template:
    metadata:
      labels:
        aadpodidbinding: bluesky-decryptor  # match the AzureIdentityBinding selector
    spec:
      containers:
      - name: manager
        env:
        - name: AZURE_AUTH_METHOD
          value: msi
```

Sample for the Patch

```
# ./clusters/play/flux-sysetm/sops-kustomize-patch.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: kustomize-controller
  namespace: flux-system
spec:
  template:
    metadata:
      labels:
        aadpodidbinding: bluesky-decryptor # match the AzureIdentityBinding selector
    spec:
      containers:
      - name: manager
        env:
        - name: AZURE_AUTH_METHOD
          value: msi
```

### Referencing the SOPs Decryption Provider

We need to notify the Flux kustomize-controller that the manifest under app/play need to use SOP.

Update cluster/play/application.yaml with the following

```
apiVersion: kustomize.toolkit.fluxcd.io/v1beta1
kind: Kustomization
metadata:
  name: app
  namespace: flux-system
spec:
  interval: 1m0s
  path: ./app/play
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  validation: client
  decryption: ## Add this
    provider: sops

```

### Encrypt Secrets

 We will be putting all the cluster secrets in the same folder under clusters/play/secrets. Additionally, we can create a default sops config to specific block to encrypt and the cryptographic key to use. 

Run the following command to encrypt the secret

```
sops -e --in-place sample-secret.yaml > sample-secret-enc.yaml
```

### Accessing the Secret

A sample of how the encrypted secret can be used to accessed a private helm repository 

```
# ./app/play/helm-repository.yaml

apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: HelmRepository
metadata:
  name: bluesky-private-registry
  namespace: default
spec:
  interval: 30m0s
  url: https://private-registry.bluesky.io/chartrepo/demo-app
  secretRef:
    name: demoapp-credentials
```