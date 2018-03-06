#! /bin/bash

set -e
set -o pipefail

IMAGE=${1}

DOCKER_APP_PORT='8080'
DOCKER_APP_CONTAINER_NAME='app'
DOCKER_MYSQL_PORT='3306'
DOCKER_MYSQL_CONTAINER_NAME='mysql'

test_software_with_inmemory_database () {
  mvn verify -Pdefault
}

test_software_with_dev_database () {
  mvn verify -Pdev
}

test_software_with_staging_database () {
  mvn verify -Pstaging
}

test_docker_access () {
  start_mysql && sleep 3
  start_application && sleep 3
  test_http_app_access
  stop_application
  stop_mysql
}

test_http_app_access () {
  STATUS_CODE=$(curl -v -L --write-out %{http_code} --show-error --silent --output /dev/null "http://${DOCKER_HOST_ADDRESS}:$DOCKER_APP_PORT/app")

  if [ "$STATUS_CODE" -ne "200" ]; then
    echo "Site status changed to $STATUS_CODE" && exit 1
  fi
}

start_mysql () {
  \docker run --name $DOCKER_MYSQL_CONTAINER_NAME \
  -p $DOCKER_MYSQL_PORT:3306 \
  -e MYSQL_ROOT_PASSWORD='secretpassword' \
  -e MYSQL_DATABASE='appdb' \
  -e MYSQL_USER='appuser' \
  -e MYSQL_PASSWORD='apppassword' \
  -d mysql/mysql-server:5.6
}

start_application () {
  \docker run --name $DOCKER_APP_CONTAINER_NAME \
  -p $DOCKER_APP_PORT:8080 \
  --link $DOCKER_MYSQL_CONTAINER_NAME:mysql \
  -d $IMAGE
}

stop_application () {
  \docker stop $DOCKER_APP_CONTAINER_NAME && docker rm $DOCKER_APP_CONTAINER_NAME;
}

stop_mysql () {
  \docker stop $DOCKER_MYSQL_CONTAINER_NAME && docker rm $DOCKER_MYSQL_CONTAINER_NAME;
}

test_software_with_inmemory_database
test_software_with_dev_database
test_software_with_staging_database
test_docker_access