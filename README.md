[![Build Status](https://travis-ci.org/misterjoshua/k8s-pipeline-setup.svg?branch=master)](https://travis-ci.org/misterjoshua/k8s-pipeline-setup)

# Kubernetes Pipeline Setup Script

This script downloads `helm` and `kubectl`, then configures kubectl to authenticate with the master, so that you can deploy to Kubernetes with less boilerplate in your pipeline step.

## Basic Usage

To use this script, you would typically set a few environment variables, download the script, and then run it. This can be done inline as follows:

```
# Download and set up kubectl and helm (use this script)
K8S_SERVER=https://your-master/ \
K8S_USERNAME=yourusername \
K8S_PASSWORD=yourpassword \
bash <(curl https://raw.githubusercontent.com/misterjoshua/k8s-pipeline-setup/master/setup.sh)

# Deploy using kubectl set
kubectl set image deployment/name containername=image:tag

# Deploy using kubectl apply
kubectl apply -f resources/

# Deploy using helm upgrade
helm upgrade --install --values values.yaml releasename chart/path
```

> Note: If you're using a build pipeline, it may be more convenient to set environment variables at the pipeline level.

## Environment Variables

| Variables | Description |
| --------- | ----------- |
| `K8S_SERVER` (Required) | The URL to your master server. (Example: `https://yourdomain:16443/`)
| `K8S_USERNAME` and `K8S_PASSWORD` | Enables basic authentication. Set these variables to your username and password respectively.
| `K8S_CLIENT_CRT` and `K8S_CLIENT_KEY` | Enables client certificate authentication. Set these variables to base64 strings containing the PEM format client certificate and client key respectively.
| `K8S_CA_CRT` | Enables tls verification. Set this variable to a base64 encoded certificate for the master server's certificate authority, in PEM format.
| `K8S_TOKEN` | Enables bearer token authentication. Set this variable to the bearer token.
| `DOWNLOAD_KUBECTL` | Set to `no` to skip downloading helm or set to a specific version of kubectl to download that version. (Example: `v1.16.2`)
| `DOWNLOAD_HELM` | Set to `no` to skip downloading helm or set to a specific version of helm to download that version. (Example: `v2.14.3`)

## Self Testing

This script can self-test. Run `setup.sh selftest` to have the script test itself in your pipeline.

## Security Considerations

Given that this script handles credentials to access your kubernetes cluster, I encourage all responsible users to review the source and to cache a copy of the script in their own repository.
