#!/bin/bash

DATASET_DIR=/home/new_cloud_cxl/extra_space_2TB/CXL_2nd_year_mid/Data

VECTORDB_CONTAINER=vectorDB_container
VECTORDB_IMAGE=qdrant/qdrant
QDRANT_STORAGE=$DATASET_DIR/qdrant_storage

INSERT_CONTAINER=insert_container
INSERT_IMAGE=loadgen_image # use loadgen_image to insert embeddings
KNOWLEDGE_DIR=$DATASET_DIR/c4_100gb_preprocessed
DOCUMENT_COUNT=10000 # change this to 100000000(1B) for c4_100gb_preprocessed

NET=my_network


function wait_for_vectordb_ready() {
  echo "Waiting for VectorDB Container to be ready..."
  while true; do
    # Try a curl request to /collections
    if curl -sf http://localhost:6333/collections >/dev/null 2>&1; then
      echo "VectorDB Container is ready."
      break
    else
      sleep 1
    fi
  done
}

# Docker 네트워크가 없으면 생성
docker network inspect $NET > /dev/null 2>&1 || docker network create $NET

docker run -d \
    --name $VECTORDB_CONTAINER\
    --network $NET \
    -p 6333:6333 \
    -v $QDRANT_STORAGE:/qdrant/storage \
    $VECTORDB_IMAGE

wait_for_vectordb_ready

echo "Starting container ${INSERT_CONTAINER}..."

# Docker 컨테이너 실행 (백그라운드로 실행)
docker run -it --rm \
  --name $INSERT_CONTAINER \
  --network $NET \
  -v $KNOWLEDGE_DIR:/app/wiki_test \
  $INSERT_IMAGE python3 /app/build_vectorDB.py --document-count=$DOCUMENT_COUNT # insert max document count (~72M for c4_100gb_preprocessed)

echo "Waiting for container ${INSERT_CONTAINER} to finish..."

# 현재 컨테이너 종료 대기
docker wait "${INSERT_CONTAINER}"

echo "Container ${INSERT_CONTAINER} has finished. Proceeding to the next container."
