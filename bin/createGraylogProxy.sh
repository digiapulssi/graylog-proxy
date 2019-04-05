#!/bin/bash

set -e

# Configuration directory for proxy
CONFIG_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/haproxy"
# Docker container name
CONTAINER_NAME=graylog-proxy
# Docker image to use
HAPROXY_IMAGE=haproxy:1.7-alpine

# Default configuration values
API_PUBLISH_PORT=8080
BEATS_PUBLISH_PORT=5044
BEATS_SERVER_PORT=5044
PROXY_ADDRESS=0.0.0.0

if [ "`docker ps -qaf name=${CONTAINER_NAME}`" != "" ] ; then
  read -p "Docker container with name ${CONTAINER_NAME} already exists, delete [y/N]: " -n1 input
  echo ""
  if [ "y" == "$input" ]; then
    echo "Stopping/removing old proxy container..."
    docker stop ${CONTAINER_NAME} >/dev/null
    docker rm ${CONTAINER_NAME} >/dev/null
  else
    echo "Terminated."
    exit 0
  fi
fi

if [ ! -d "${CONFIG_DIR}" ]; then
  mkdir ${CONFIG_DIR}
fi

# Interactive configuration
read -p "Enter bind address for graylog-proxy [${PROXY_ADDRESS}]: " input
PROXY_ADDRESS=${input:-$PROXY_ADDRESS}

read -p "Enter logging server or next proxy addresses (separate addresses with comma or space): " LOGGING_SERVER

read -p "Use TLSv12 client certificate for connections [Y/n]: " -n1 input
echo ""

USE_TLSv12=${input:-y}

if [ "y" == "$USE_TLSv12" ]; then
  API_SERVER_PORT=8443
  TLS_CONFIG="ssl crt /usr/local/etc/haproxy/cert/client.pem ca-file /usr/local/etc/haproxy/cert/server_ca.pem check"

  if [ ! -d "${CONFIG_DIR}/cert" ]; then
    mkdir "${CONFIG_DIR}/cert"
  fi
else
  API_SERVER_PORT=8080
  TLS_CONFIG=""
fi

read -p "Enter published API port that graylog-sidecar will connect to at this host [${API_PUBLISH_PORT}]: " input
API_PUBLISH_PORT=${input:-$API_PUBLISH_PORT}

read -p "Enter published Beats port that graylog-sidecar/filebeat will connect to at this host [${BEATS_PUBLISH_PORT}]: " input
BEATS_PUBLISH_PORT=${input:-$BEATS_PUBLISH_PORT}

read -p "Enter server API port that graylog-proxy will connect to at ${LOGGING_SERVER} [${API_SERVER_PORT}]: " input
API_SERVER_PORT=${input:-$API_SERVER_PORT}

read -p "Enter server Beats port that graylog-proxy will connect to at ${LOGGING_SERVER} [${BEATS_SERVER_PORT}]: " input
BEATS_SERVER_PORT=${input:-$BEATS_SERVER_PORT}

echo Generating proxy configuration to ${CONFIG_DIR}/haproxy.cfg...
echo -n """
global
    tune.ssl.default-dh-param 2048
    log 172.17.0.1 local2

defaults
    log     global
    mode    tcp
    option  tcplog
    timeout connect 5000
    timeout client  50000
    timeout server  50000

listen graylog_api
    mode tcp
    bind *:${API_PUBLISH_PORT}
""" >${CONFIG_DIR}/haproxy.cfg

idx=1
for server in ${LOGGING_SERVER//,/ }
do
  echo -n """
    server graylog${idx} ${server}:${API_SERVER_PORT} ${TLS_CONFIG}""" >>${CONFIG_DIR}/haproxy.cfg
  ((idx++))
done

echo -n """

listen graylog_beats
    mode tcp
    bind *:${BEATS_PUBLISH_PORT}
""" >>${CONFIG_DIR}/haproxy.cfg

idx=1
for server in ${LOGGING_SERVER//,/ }
do
  echo -n """
    server graylog${idx} ${server}:${BEATS_SERVER_PORT} ${TLS_CONFIG}""" >>${CONFIG_DIR}/haproxy.cfg
  ((idx++))
done

echo Creating proxy container...
docker create \
  --restart unless-stopped \
  --name ${CONTAINER_NAME} \
  -p ${PROXY_ADDRESS}:${BEATS_PUBLISH_PORT}:${BEATS_PUBLISH_PORT} \
  -p ${PROXY_ADDRESS}:${API_PUBLISH_PORT}:${API_PUBLISH_PORT} \
  -v ${CONFIG_DIR}:/usr/local/etc/haproxy \
  ${HAPROXY_IMAGE}

echo ""
if [ "y" == "${USE_TLSv12}" ]; then
  echo Configured with TLSv12. Before starting the container, copy client.pem and server_ca.pem files to ${CONFIG_DIR}/cert and update their file permissions to 0400.
fi
echo To start the proxy container, run:
echo     docker start ${CONTAINER_NAME}

echo All done.
