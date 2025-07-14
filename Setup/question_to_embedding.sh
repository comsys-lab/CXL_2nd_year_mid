#!/bin/bash

set -x

###########################################################################
#########################      CONFIGURATIONS     #########################
###########################################################################

### Container & Image NAME
EMBEDDING_CONTAINER=preprocessing_container
EMBEDDING_IMAGE=preprocessing_image  

# change the path to the dataset directory
DATASET_DIR=/home/new_cloud_cxl/binbin
DATASET_PATH='/app/Data/bioasq'

echo "Loading Embedding Container..."

docker run -it --rm \
    --name $EMBEDDING_CONTAINER \
    -v $DATASET_DIR:/app/Data \
    $EMBEDDING_IMAGE python3 /app/question_to_embedding.py \
                            --dataset-dir=$DATASET_PATH \
                            --split='train' \
                            --store-question --store-embedding