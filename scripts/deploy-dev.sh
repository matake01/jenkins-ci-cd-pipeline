#! /bin/bash

set -e
set -o pipefail

APP_DOMAIN_URL="<APP_DOMAIN_URL>"

DOCKER_REPOSITORY=${1}
DOCKER_REGISTRY="<DOCKER_REGISTRY>"
DOCKER_IMAGE="$DOCKER_REGISTRY/$DOCKER_REPOSITORY-dev:latest"

DOCKER_REGISTRY_URL="<DOCKER_REGISTRY_URL>"
DOCKER_REGISTRY_USERNAME="<DOCKER_REGISTRY_USERNAME>"
DOCKER_REGISTRY_PASSWORD="<DOCKER_REGISTRY_PASSWORD>"

SSH_HOST_ADDRESS="<SSH_HOST_ADDRESS>"
SSH_HOST_PORT="<SSH_HOST_PORT>"
SSH_HOST_USERNAME="<SSH_HOST_USERNAME>"

push_image_to_dev_docker_repo() {
  docker logout && docker login -u $DOCKER_REGISTRY_USERNAME -p $DOCKER_REGISTRY_PASSWORD $DOCKER_REGISTRY_URL
  docker tag $DOCKER_REPOSITORY $DOCKER_IMAGE && docker push $DOCKER_IMAGE && docker rmi --force $DOCKER_IMAGE
}

deploy_on_dev_server() {
  ssh -p $SSH_HOST_PORT $SSH_HOST_USERNAME@$SSH_HOST_ADDRESS "
    docker logout && docker login -u $DOCKER_REGISTRY_USERNAME -p $DOCKER_REGISTRY_PASSWORD $DOCKER_REGISTRY_URL && \
    docker ps -a | awk '{ print \$1,\$2 }' | grep $DOCKER_REPOSITORY | awk '{ print \$1 }' | xargs -I {} docker stop {} && \
    docker ps -a | awk '{ print \$1,\$2 }' | grep $DOCKER_REPOSITORY | awk '{ print \$1 }' | xargs -I {} docker rm {} && \
    docker rmi --force $DOCKER_IMAGE && docker pull $DOCKER_IMAGE && \
    docker run -p 8080:8080 \
    --name $DOCKER_REPOSITORY \
    -d $DOCKER_IMAGE
  "
}

test_http_app_access () {
  printf " - Test HTTP application access.\n"
  STATUS_CODE=$(curl -v -L --write-out %{http_code} --show-error --silent --output /dev/null "$APP_DOMAIN_URL")
  if [ "$STATUS_CODE" -ne "200" ]; then
    printf "Failed to HTTP access deployment. Response Code: $STATUS_CODE\n" && exit 1
  fi
}

validate_environment
push_image_to_dev_docker_repo
deploy_on_dev_server
sleep 2
test_http_app_access