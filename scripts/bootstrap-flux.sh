#!/bin/sh

# Export personal access token
export GITHUB_TOKEN=<your-token>
export GITHUB_USER=<your-username>

flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=bluesky-flux-sops-azure-template \
  --branch=master \
  --path=./clusters/play \
  --personal

