#!/bin/bash

set -x

###########################################################################
#########################      CONFIGURATIONS     #########################
###########################################################################

### Container & Image NAME
EMBEDDING_CONTAINER=preprocessing_container
EMBEDDING_IMAGE=preprocessing_image  

# change the path to the embedding model directory
EMBEDDING_MODEL_DIR="/home/new_cloud_cxl/extra_space_2TB/binbin/CXL_2nd_year_mid/Data/all-MiniLM-L6-v2"

# change the path to the dataset directory
DATASET_DIR=/home/new_cloud_cxl/extra_space_2TB/binbin/CXL_2nd_year_mid/Data
DATASET_PATH='/app/Data/bioasq'

echo "Loading Embedding Container..."

docker run -it --rm \
    --name $EMBEDDING_CONTAINER \
    -v $DATASET_DIR:/app/Data \
    -v $EMBEDDING_MODEL_DIR:/app/embedding_model \
    $EMBEDDING_IMAGE python3 /app/question_to_embedding.py \
                            --dataset-dir=$DATASET_PATH \
                            --embedding-model-dir=/app/embedding_model \
                            --split='train' \
                            --store-question --store-embedding