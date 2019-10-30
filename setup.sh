#!/bin/bash -e

# MIT License
#
# Copyright (c) 2019 Joshua Kellendonk
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

BIN_DIR=${BIN_DIR:-/usr/local/bin}
TMP_DIR=${TMP_DIR:-/tmp}
CONTEXT_NAME=${CONTEXT_NAME:-deploy}

function die() {
  log $*
  exit 1
}

function log() {
  echo "$*" >&2
}

function isScriptRun() {
  [ "$(basename $0)" = "setup.sh" ] && return 0
  [ "$(dirname $0)" = "/dev/fd" ] && return 0
  [ "$0" = "bash" ] && return 0
  return 1
}

function testCommands() {
  log "Testing for required cli tools"
  [ -x "$(command -v curl)" ] || die "This script requires the curl command"
  [ -x "$(command -v base64)" ] || die "This script requires the base64 command"
}

function downloadKubectl() {
  VERSION=$1
  if [ -z "$VERSION" ]; then
    VERSION=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
  fi

  log "Downloading kubectl $VERSION"
  curl -o $BIN_DIR/kubectl -L https://storage.googleapis.com/kubernetes-release/release/$VERSION/bin/linux/amd64/kubectl
  chmod +x $BIN_DIR/kubectl

  $BIN_DIR/kubectl version --client >/dev/null
}

function downloadHelm() {
  VERSION=${1:-v2.14.3}

  log "Downloading helm"
  curl https://get.helm.sh/helm-$VERSION-linux-amd64.tar.gz | tar -C $TMP_DIR -zx
  chmod +x $TMP_DIR/linux-amd64/helm
  mv $TMP_DIR/linux-amd64/helm $BIN_DIR/helm
  rm -rf $TMP_DIR/linux-amd64

  $BIN_DIR/helm version --client >/dev/null
}

function configureKubectl() {
  log "Configuring kubectl"
  base64 -d <<<$K8S_CRT >k.crt

  KEY_DIR=${KEY_DIR:-./}

  # Set up credentials
  if [ ! -z "$K8S_CLIENT_CRT" ]; then
    log "Setting client certificate"
    CLIENT_CERT_FILE=$KEY_DIR/c.crt
    base64 -d <<<$K8S_CLIENT_CRT >$CLIENT_CERT_FILE
    kubectl config set-credentials $CONTEXT_NAME --embed-certs=true --client-certificate=$CLIENT_CERT_FILE
  fi

  if [ ! -z "$K8S_CLIENT_KEY" ]; then
    log "Setting client key"
    CLIENT_KEY_FILE=$KEY_DIR/c.key
    base64 -d <<<$K8S_CLIENT_KEY >$CLIENT_KEY_FILE
    kubectl config set-credentials $CONTEXT_NAME --embed-certs=true --client-key=$CLIENT_KEY_FILE
  fi

  if [ ! -z "$K8S_USERNAME" -a ! -z "$K8S_PASSWORD" ]; then
    log "Setting user/pass"
    kubectl config set-credentials $CONTEXT_NAME --username="$K8S_USERNAME" --password="$K8S_PASSWORD"
  fi

  if [ ! -z "$K8S_TOKEN" ]; then
    log "Setting bearer token"
    kubectl config set-credentials $CONTEXT_NAME --token=$K8S_TOKEN
  fi

  # Set up the cluster
  if [ ! -z "$K8S_CA_CRT" ]; then
    log "Setting cluster certificate authority"
    CA_CERT_FILE=$KEY_DIR/k.crt
    base64 -d <<<$K8S_CA_CRT >$CA_CERT_FILE
    kubectl config set-cluster $CONTEXT_NAME --certificate-authority=$CA_CERT_FILE
  else
    log "Setting cluster to skip tls verify. WARNING: Insecure to man-in-the-middle."
    kubectl config set-cluster $CONTEXT_NAME --insecure-skip-tls-verify
  fi

  if [ ! -z "$K8S_SERVER" ]; then
    log "Setting cluster server address"
    kubectl config set-cluster $CONTEXT_NAME --server=$K8S_SERVER
  fi

  log "Creating context $CONTEXT_NAME"
  kubectl config set-context $CONTEXT_NAME --cluster=$CONTEXT_NAME --user=$CONTEXT_NAME

  log "Using the context"
  kubectl config use-context $CONTEXT_NAME
}

function testKubectl() {
  log "Testing configuration"
  if [ ! -z "$K8S_CRT" ]; then
    kubectl version
  else
    kubectl version --insecure-skip-tls-verify
  fi
}

function setup() {
  [ -z "$K8S_SERVER" ] && die "Missing K8S_SERVER env var"

  log "Setting up kubectl and helm"

  [ ! -d "$BIN_DIR" ] && mkdir -p $BIN_DIR

  testCommands
  downloadKubectl
  downloadHelm
  configureKubectl
  testKubectl
}

function selftest() {
  log "Running self test"

  SELFTEST_DIR=$TMP_DIR/selftest
  rm -rf $SELFTEST_DIR
  mkdir -p $SELFTEST_DIR

  log "Testing default kubectl version (stable) download"
  BIN_DIR=$SELFTEST_DIR downloadKubectl 2>/dev/null
  $SELFTEST_DIR/kubectl version --client | grep "^Client Version" >/dev/null || die "Didn't get kubectl 'stable'"

  log "Testing arbitrary kubectl version download"
  BIN_DIR=$SELFTEST_DIR downloadKubectl v1.16.0 2>/dev/null
  $SELFTEST_DIR/kubectl version --client | grep "v1.16.0" >/dev/null || die "Didn't get kubectl 'v1.16.0'"

  log "Testing default helm version download"
  BIN_DIR=$SELFTEST_DIR downloadHelm 2>/dev/null
  $SELFTEST_DIR/helm version --client | grep "^Client:" >/dev/null || die "Didn't get a helm version"

  log "Testing arbitrary helm version download"
  BIN_DIR=$SELFTEST_DIR downloadHelm v2.14.0 2>/dev/null
  $SELFTEST_DIR/helm version --client | grep "v2.14.0" >/dev/null || die "Didn't get a helm version"

  # Create a kubectl mock.
  function kubectl() {
    echo $*
  }

  FICTITIOUS_SERVER=https://someserver:port
  FICTITIOUS_CERT=cert
  FICTITIOUS_KEY=key

  log "Testing for set-context and set-cluster"
  SIMPLE=$(K8S_SERVER=$FICTITIOUS_SERVER configureKubectl 2>/dev/null)
  grep "set-context" <<<$SIMPLE >/dev/null || die "Didn't set-context"
  grep "set-cluster.*--server=$FICTITIOUS_SERVER" <<<$SIMPLE >/dev/null || die "Didn't set-cluster"

  log "Testing basic authentication"
  USERPASS=$(
    K8S_USERNAME=someuser
    K8S_PASSWORD=somepassword
    K8S_SERVER=$FICTITIOUS_SERVER
    configureKubectl 2>/dev/null)
  grep "set-credentials.*--username=someuser" <<<$USERPASS >/dev/null || die "Didn't set username"
  grep "set-credentials.*--password=somepass" <<<$USERPASS >/dev/null || die "Didn't set password"
  grep "set-cluster.*--server=$FICTITIOUS_SERVER" <<<$USERPASS >/dev/null || die "Didn't set server"

  log "Testing bearer token authentication"
  TOKEN=$(
    K8S_TOKEN=abcd
    K8S_SERVER=$FICTITIOUS_SERVER
    configureKubectl 2>/dev/null)
  grep "set-credentials.*--token=abcd" <<<$TOKEN >/dev/null || die "Didn't set token"

  log "Testing client certificate authentication"
  CLIENTCERT=$(
    K8S_CLIENT_CRT=$(base64 <<<$FICTITIOUS_CERT)
    K8S_CLIENT_KEY=$(base64 <<<$FICTITIOUS_KEY)
    K8S_SERVER=$FICTITIOUS_SERVER
    KEY_DIR=$SELFTEST_DIR
    configureKubectl 2>/dev/null)
  grep "set-credentials.*--client-certificate=$SELFTEST_DIR/c.crt" <<<$CLIENTCERT >/dev/null || die "Didn't set client certificate"
  grep "set-credentials.*--client-key=$SELFTEST_DIR/c.key" <<<$CLIENTCERT >/dev/null || die "Didn't set client key"
  [ "$(cat $SELFTEST_DIR/c.crt)" = "$FICTITIOUS_CERT" ] || die "Invalid cert file content"
  [ "$(cat $SELFTEST_DIR/c.key)" = "$FICTITIOUS_KEY" ] || die "Invalid key file content"

  log "Testing all the auth methods provided at once"
  KITCHENSINK=$(
    K8S_USERNAME=someuser
    K8S_PASSWORD=somepassword
    K8S_TOKEN=abcd
    K8S_CLIENT_CRT=$(base64 <<<$FICTITIOUS_CERT)
    K8S_CLIENT_KEY=$(base64 <<<$FICTITIOUS_KEY)
    K8S_SERVER=$FICTITIOUS_SERVER
    KEY_DIR=$SELFTEST_DIR \
    configureKubectl 2>/dev/null)
  grep "set-context" <<<$SIMPLE >/dev/null || die "Didn't set-context"
  grep "set-credentials.*--username=someuser" <<<$USERPASS >/dev/null || die "Didn't set username"
  grep "set-credentials.*--password=somepass" <<<$USERPASS >/dev/null || die "Didn't set password"
  grep "set-credentials.*--token=abcd" <<<$TOKEN >/dev/null || die "Didn't set token"
  grep "set-credentials.*--client-certificate=$SELFTEST_DIR/c.crt" <<<$CLIENTCERT >/dev/null || die "Didn't set client certificate"
  grep "set-credentials.*--client-key=$SELFTEST_DIR/c.key" <<<$CLIENTCERT >/dev/null || die "Didn't set client key"
  grep "set-cluster.*--server=$FICTITIOUS_SERVER" <<<$USERPASS >/dev/null || die "Didn't set server"

  log "Self test succeeded"
}

if isScriptRun; then
  case "$1" in
    selftest) selftest ;;
    *) setup
  esac
fi
