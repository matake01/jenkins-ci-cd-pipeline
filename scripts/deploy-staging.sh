#! /bin/bash

set -e
set -o pipefail

APP_DOMAIN_URL="<APP_DOMAIN_URL>"

VERSION=${1}
BRANCH_NAME=${2}

DOCKER_REPOSITORY=${3}

DOCKER_DEV_REGISTRY="<DOCKER_DEV_REGISTRY>"
DOCKER_DEV_IMAGE="$DOCKER_DEV_REGISTRY/$DOCKER_REPOSITORY:$VERSION"

DOCKER_DEV_REGISTRY_URL="<DOCKER_REGISTRY_URL>"
DOCKER_DEV_REGISTRY_USERNAME="<DOCKER_REGISTRY_USERNAME>"
DOCKER_DEV_REGISTRY_PASSWORD="<DOCKER_REGISTRY_PASSWORD>"

DOCKER_HUB_REGISTRY="<DOCKER_HUB_REGISTRY>"
DOCKER_HUB_IMAGE="$DOCKER_HUB_REGISTRY/$DOCKER_REPOSITORY:$VERSION"

DOCKER_HUB_REGISTRY_USERNAME="<DOCKER_REGISTRY_USERNAME>"
DOCKER_HUB_REGISTRY_PASSWORD="<DOCKER_REGISTRY_PASSWORD>"

SSH_HOST_ADDRESS="<SSH_HOST_ADDRESS>"
SSH_HOST_PORT="<SSH_HOST_PORT>"
SSH_HOST_USERNAME="<SSH_HOST_USERNAME>"

validate_version() {
  if git ls-remote origin refs/tags/$VERSION | grep -w "^$VERSION$"
  then
    printf "Error: Version '$VERSION' already exists.\n" && exit 1
  fi
}

push_image_to_dev_docker_repo() {
  docker logout && docker login -u $DOCKER_DEV_REGISTRY_USERNAME -p $DOCKER_DEV_REGISTRY_PASSWORD $DOCKER_DEV_REGISTRY_URL
  docker tag $DOCKER_REPOSITORY $DOCKER_DEV_IMAGE && docker push $DOCKER_DEV_IMAGE && docker rmi --force $DOCKER_DEV_IMAGE
}

push_image_to_docker_hub() {
  docker logout && docker login -u $DOCKER_HUB_REGISTRY_USERNAME -p $DOCKER_HUB_REGISTRY_PASSWORD
  docker tag $DOCKER_REPOSITORY $DOCKER_HUB_IMAGE && docker push $DOCKER_HUB_IMAGE && docker rmi --force $DOCKER_HUB_IMAGE
}

deploy_on_staging_server() {
  ssh -p $SSH_HOST_PORT $SSH_HOST_USERNAME@$SSH_HOST_ADDRESS "
    docker logout && docker login -u <DOCKER_HUB_USERNAME> -p <DOCKER_HUB_PASSWORD> && \
    docker ps -a | awk '{ print \$1,\$2 }' | grep $DOCKER_REPOSITORY | awk '{ print \$1 }' | xargs -I {} docker stop {} && \
    docker ps -a | awk '{ print \$1,\$2 }' | grep $DOCKER_REPOSITORY | awk '{ print \$1 }' | xargs -I {} docker rm {} && \
    docker images -a | awk '{ print \$1, \$2 }' | grep '$DOCKER_HUB_REGISTRY/$DOCKER_REPOSITORY $VERSION' | awk '{ printf \"%s:%s\", \$1, \$2 }' && \
    docker pull $DOCKER_HUB_IMAGE && \
    docker run -p 8080:8080 \
    --name $DOCKER_REPOSITORY \
    -d $DOCKER_HUB_IMAGE
  "
}

create_and_push_tag_to_git() {
  git tag -a $VERSION -m "$VERSION" -m "Jenkins Job ${JOB_NAME} Build #${BUILD_NUMBER} from branch ${GIT_BRANCH} (${BUILD_URL})"
  git push origin $VERSION
}

test_http_app_access() {
  STATUS_CODE=$(curl -v -L --write-out %{http_code} --show-error --silent --output /dev/null "$APP_DOMAIN_URL")
  if [ "$STATUS_CODE" -ne "200" ]; then
    printf "Failed to HTTP access deployment. Response Code: $STATUS_CODE\n" && exit 1
  fi
}

git fetch --tags --prune
validate_version
git checkout $GIT_BRANCH
push_image_to_docker_dev_repo
push_image_to_docker_hub
create_and_push_tag_to_git
deploy_on_staging_server
sleep 2
test_http_app_access
