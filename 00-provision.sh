#!/bin/bash

export EDB_SUBSCRIPTION_TOKEN=`cat ${HOME}/.tokens/edb_subscription_token`
export DOCKER_CLI_HINTS=off
export EDB_PLATFORM_VERSION=2026.5.1
export AUTHENTICATION_PASSWORD='password'

# Create kind cluster
kind create cluster --config kind-config.yaml
kubectl config use-context kind-edbpgai
kubectl cluster-info --context kind-edbpgai

# Create image pull secrets
edbctl image-pull-secret create \
  --username pgai-platform \
  --password $EDB_SUBSCRIPTION_TOKEN \
  --registry docker.enterprisedb.com \
  --operator-username pgai-platform \
  --operator-password $EDB_SUBSCRIPTION_TOKEN \
  --operator-registry docker.enterprisedb.com

edbctl setup create-install-secrets --version $EDB_PLATFORM_VERSION

# Object storage secret
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: edb-object-storage
  namespace: default
stringData:
    auth_type: credentials
    aws_endpoint_url_s3: http://127.0.0.1:9000
    aws_access_key_id: 0T0SQ76DX4509RTSYJNP
    aws_secret_access_key: AGlmuoNCwx2D8eXpJbNN14f2ugzGy+tGp7vnGlC+
    bucket_name: hcpdemo
    aws_region: us-east-1
    server_side_encryption_disabled: "true"
    aws_request_checksum_calculation: "when_required"
    aws_response_checksum_validation: "when_required"
EOF

kubectl create namespace upm-lakekeeper --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
   name: pg-confounding-key
   namespace: upm-lakekeeper
stringData:
   PG_CONFOUNDING_KEY: "+5F8mrPLdGSMrH6L69qT3q5GuHmaLAvXa/xW/iZOJZw="
EOF

# Langflow
kubectl create secret generic langflow-secret -n default \
  --from-literal LANGFLOW_SUPERUSER=langflow \
  --from-literal LANGFLOW_SECRET_KEY="ddJeo3XhwtBpPd71O0nSymJJKQuM8Sc70-kDN_UfguA" \
  --from-literal LANGFLOW_SUPERUSER_PASSWORD="V28HeWD6xQc8qPBW"
kubectl annotate secret langflow-secret -n default replicator.v1.mittwald.de/replicate-to="upm-langflow,upm-beaco-ff-base"

# Fernet key 
FERNET_KEY=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64)
kubectl create namespace upm-dex --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
    name: dex-fernet-key
    namespace: upm-dex
stringData:
    fernet-key: ${FERNET_KEY}
EOF

## Input password for Portal user and generate hash using htpasswd
export AUTHENTICATION_PASSWORD_HASH="$(echo -n $AUTHENTICATION_PASSWORD | htpasswd -BinC 10 admin | cut -d: -f2)"

cat <<EOF > static-passwords.yaml
staticPasswords:
- email: owner@mycompany.com
  hash: "$AUTHENTICATION_PASSWORD_HASH"
  userID: c5998173-a605-449a-a9a5-4a9c33e26df7
  username: Owner MyCompany
EOF
kubectl create secret generic hm-portal-bootstrap --namespace default --from-literal=fernet-key="$FERNET_KEY" --from-file=static-passwords.yaml=static-passwords.yaml
kubectl annotate secret hm-portal-bootstrap --namespace default  replicator.v1.mittwald.de/replicate-to=upm-dex

# Install the helm chart
helm repo add edbpgai "https://downloads.enterprisedb.com/${EDB_SUBSCRIPTION_TOKEN}/pgai-platform/helm/charts"
helm repo update
helm search repo -l edbpgai/edbpgai-bootstrap
helm upgrade -n edbpgai-bootstrap --install --version ${EDB_PLATFORM_VERSION} -f kind-values.yaml edbpgai-bootstrap edbpgai/edbpgai-bootstrap
