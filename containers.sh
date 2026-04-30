#!/usr/bin/env bash

usage() {
  echo "Usage: $0 {start|stop|status}"
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

ACTION=$1

containers=$(docker ps -a --format '{{.Names}} {{.ID}}' | awk '$1 ~ /^edbpgai-/ {print $2}')

if [[ -z "$containers" ]]; then
  echo "No containers found for EDBPGAI"
  exit 1
fi

case "$ACTION" in
  start)
    echo "Starting EDBPGAI containers..."
    docker start $containers
    ;;
  stop)
    echo "Stopping EDBPGAI containers..."
    docker stop $containers
    ;;
  status)
    echo "Containers for EDBPGAI:"
    docker ps -a --format '{{.Names}}\t{{.Status}}' | awk '$1 ~ /^edbpgai-/'
    ;;
  *)
    usage
    ;;
esac
