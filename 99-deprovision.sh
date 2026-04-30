#!/bin/bash

kind delete cluster --name edbpgai
helm repo remove edbpgai
helm repo update

#docker container stop edbpgai-minio
#docker container rm edbpgai-minio
#rm -rf minio/* minio/.* 2>/dev/null
