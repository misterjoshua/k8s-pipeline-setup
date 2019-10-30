[![Build Status](https://travis-ci.org/misterjoshua/k8s-pipeline-setup.svg?branch=master)](https://travis-ci.org/misterjoshua/k8s-pipeline-setup)

# Helm Pipeline Setup Script

This script downloads `helm` and `kubectl` in a build pipeline and configures kubectl to authenticate with the master so that deployment

## Basic Usage

To use this script, you would typically set a few environment variables, download the script, and then run it. This can be done inline as follows:

```
K8S_SERVER=https://your-master/ \
K8S_USERNAME=yourusername \
K8S_PASSWORD=yourpassword \
bash <(curl https://raw.githubusercontent.com/misterjoshua/k8s-pipeline-setup/master/setup.sh)
```

> Note: If you're using a build pipeline, it may be more convenient to set environment variables at the pipeline level.

## Environment Variables

| Variables | Description |
| --------- | ----------- |
| `K8S_SERVER` (Required) | The URL to your master server. (e.g., `https://yourdomain:16443/`)
| `K8S_USERNAME` and `K8S_PASSWORD` | Enables basic authentication. Set these variables to your username and password respectively.
| `K8S_CLIENT_CRT` and `K8S_CLIENT_KEY` | Enables client certificate authentication. Set these variables to base64 strings containing PEM format the client certificate and client key respectively.
| `K8S_CA_CRT` | Enables tls verification. Set this variable to a base64 encoded PEM format certificate.
| `K8S_TOKEN` | Enables bearer token authentication. Set this variable to the bearer token.

## Security Considerations

Given that this script handles credentials to access your kubernetes cluster, I encourage all responsible users to review the source and to cache a copy of the script in their own repository.
