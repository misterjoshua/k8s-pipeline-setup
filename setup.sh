#!/bin/bash -e

BIN_DIR=${BIN_DIR:-/usr/local/bin}
TMP_DIR=${TMP_DIR:-/tmp}
CONTEXT_NAME=${CONTEXT_NAME:-deploy}

function die() {
  echo "$*"
  exit 1
}

function testCommands() {
  echo "Testing for required cli tools"
  [ -x "$(command -v curl)" ] || die "This script requires the curl command"
  [ -x "$(command -v base64)" ] || die "This script requires the base64 command"
}

function downloadKubectl() {
  VERSION=$1
  if [ -z "$VERSION" ]; then
    VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
  fi

  echo "Downloading kubectl $VERSION"
  curl -o $BIN_DIR/kubectl -L https://storage.googleapis.com/kubernetes-release/release/$VERSION/bin/linux/amd64/kubectl
  chmod +x $BIN_DIR/kubectl

  $BIN_DIR/kubectl version --client >/dev/null
}

function downloadHelm() {
  VERSION=${1:-v2.14.3}

  echo "Downloading helm"
  curl https://get.helm.sh/helm-$VERSION-linux-amd64.tar.gz | tar -C $TMP_DIR -zx
  chmod +x $TMP_DIR/linux-amd64/helm
  mv $TMP_DIR/linux-amd64/helm $BIN_DIR/helm
  rm -rf $TMP_DIR/linux-amd64

  $BIN_DIR/helm version --client >/dev/null
}

function configureKubectl() {
  echo "Configuring kubectl"
  base64 -d <<<$KUBERNETES_CRT >k.crt

  KEY_DIR=${KEY_DIR:-./}

  # Set up credentials
  if [ ! -z "$KUBERNETES_CLIENT_CRT" ]; then
    echo "Setting client certificate"
    CLIENT_CERT_FILE=$KEY_DIR/c.crt
    base64 -d <<<$KUBERNETES_CLIENT_CRT >$CLIENT_CERT_FILE
    kubectl config set-credentials $CONTEXT_NAME --embed-certs=true --client-certificate=$CLIENT_CERT_FILE
  fi

  if [ ! -z "$KUBERNETES_CLIENT_KEY" ]; then
    echo "Setting client key"
    CLIENT_KEY_FILE=$KEY_DIR/c.key
    base64 -d <<<$KUBERNETES_CLIENT_KEY >$CLIENT_KEY_FILE
    kubectl config set-credentials $CONTEXT_NAME --embed-certs=true --client-key=$CLIENT_KEY_FILE
  fi

  if [ ! -z "$KUBERNETES_USERNAME" -a ! -z "$KUBERNETES_PASSWORD" ]; then
    echo "Setting user/pass"
    kubectl config set-credentials $CONTEXT_NAME --username="$KUBERNETES_USERNAME" --password="$KUBERNETES_PASSWORD"
  fi

  if [ ! -z "$KUBERNETES_CLIENT_TOKEN" ]; then
    echo "Setting bearer token"
    kubectl config set-credentials $CONTEXT_NAME --token=$KUBERNETES_CLIENT_TOKEN
  fi

  # Set up the cluster
  if [ ! -z "$KUBERNETES_CRT" ]; then
    echo "Setting cluster certificate authority"
    CA_CERT_FILE=$KEY_DIR/k.crt
    base64 -d <<<$KUBERNETES_CRT >$CA_CERT_FILE
    kubectl config set-cluster $CONTEXT_NAME --certificate-authority=$CA_CERT_FILE
  else
    echo "Setting cluster to skip tls verify. WARNING: Insecure to man-in-the-middle."
    kubectl config set-cluster $CONTEXT_NAME --insecure-skip-tls-verify
  fi

  if [ ! -z "$KUBERNETES_SERVER" ]; then
    echo "Setting cluster server address"
    kubectl config set-cluster $CONTEXT_NAME --server=$KUBERNETES_SERVER
  fi

  echo "Creating context $CONTEXT_NAME"
  kubectl config set-context $CONTEXT_NAME --cluster=$CONTEXT_NAME --user=$CONTEXT_NAME

  echo "Using the context"
  kubectl config use-context $CONTEXT_NAME
}

function testKubectl() {
  echo "Testing configuration"
  if [ ! -z "$KUBERNETES_CRT" ]; then
    kubectl version
  else
    kubectl version --insecure-skip-tls-verify
  fi
}

if [ "__$(basename $0)" = "__setup.sh" ]; then
  [ -z "$KUBERNETES_SERVER" ] && die "Missing KUBERNETES_SERVER env var"

  echo "Running setup."

  testCommands
  downloadKubectl
  downloadHelm
  configureKubectl
  testKubectl
fi
