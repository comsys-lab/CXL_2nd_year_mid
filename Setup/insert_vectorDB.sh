#!/bin/bash

DATASET_DIR=/home/new_cloud_cxl/

VECTORDB_IP=163.152.48.208
VECTORDB_PORT=6333
COLLECTION_NAME=wiki_passages

INSERT_CONTAINER=insert_container
INSERT_IMAGE=loadgen_image # use loadgen_image to insert embeddings
KNOWLEDGE_DIR=$DATASET_DIR/binbin
DOCUMENT_COUNT=1000000 # change this to 100000000(1B) for c4_100gb_preprocessed, insert max document count (~72M for c4_100gb_preprocessed)

NET=my_network


function wait_for_vectordb_ready() {
  echo "Waiting for VectorDB Container to be ready..."
  while true; do
    # Try a curl request to /collections
    if curl -sf http://$VECTORDB_IP:$VECTORDB_PORT >/dev/null 2>&1; then
      echo "VectorDB Container is ready."
      break
    else
      sleep 1
    fi
  done
}

wait_for_vectordb_ready

echo "Starting container ${INSERT_CONTAINER}..."

# Docker 컨테이너 실행
docker run -it --rm \
  --name $INSERT_CONTAINER \
  --network $NET \
  -v $KNOWLEDGE_DIR:/app/wiki_test \
  $INSERT_IMAGE python3 /app/build_vectorDB.py \
                      --dataset-path=/app/wiki_test \
                      --document-count=$DOCUMENT_COUNT \
                      --collection-name=$COLLECTION_NAME \
                      --host=$VECTORDB_IP \
                      --port=6333 \

echo "Waiting for container ${INSERT_CONTAINER} to finish..."

# 현재 컨테이너 종료 대기
docker wait "${INSERT_CONTAINER}"

echo "Container ${INSERT_CONTAINER} has finished. Proceeding to the next container."
