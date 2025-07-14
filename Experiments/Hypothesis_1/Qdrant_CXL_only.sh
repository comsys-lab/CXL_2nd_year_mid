#!/bin/bash

set -x

###########################################################################
#########################      CONFIGURATIONS     #########################
###########################################################################

##### Utility #####
PCM_PATH=/home/new_cloud_cxl/pcm

##### Experiment Configuration #####
# Loadgen configurations
RPS_TEST_POOL=(0 2 4 6 8 10 12 14)
LOADGEN_QUERY_COUNT=1000000

# Reqgen configurations
REQGEN_RPS=0.5
REQGEN_QUERY_COUNT=1000 #7830 is max for NQ development dataset


##### Resource Configurations #####
# Define CPU ranges for VECTORDB_CPUS
VECTORDB_CPUS=$(numactl -H | grep "node 0 cpus:" | sed 's/^node 0 cpus: //' | tr ' ' ',')
VECTORDB_MEM_NODE=2,3

# Define CPU ranges for QUESTION_CPUS
QUESTION_CPUS=$(seq 16 23 | tr '\n' ',')$(seq 48 55 | tr '\n' ',' | sed 's/,$//')
QUESTION_MEM_NODE=1

# Define CPU ranges for LOADGEN_CPUS
LOADGEN_CPUS=$(seq 24 31 | tr '\n' ',')$(seq 56 63 | tr '\n' ',' | sed 's/,$//')
LOADGEN_MEM_NODE=1


##### Docker configurations #####
# Container name
VECTORDB_CONTAINER=vectorDB_container
QUESTION_CONTAINER=question_container
LOADGEN_CONTAINER=loadgen_container

# Image name
VECTORDB_IMAGE=qdrant/qdrant
QUESTION_IMAGE=question_image
LOADGEN_IMAGE=qdrant_image

# Network
GPU_SERVER_IP='163.152.48.206' #change this to your GPU server IP
NETWORK=my_network

# Dataset direc
DATASET_DIR=/home/new_cloud_cxl/extra_space_2TB/CXL_2nd_year_mid/Data

##### Output #####
OUT=$(pwd)/out #temporal output resides here
RESULTS=$(date '+%y%m%d')_CXL_only

VECTORDB_LOG=$OUT/$VECTORDB_CONTAINER.log
QUESTION_LOG=$OUT/$QUESTION_CONTAINER.log
LOADGEN_LOG=$OUT/$LOADGEN_CONTAINER.log

###########################################################################
#########################     HELPER FUNCTIONS    #########################
###########################################################################

# Create a Docker network (ignore if it already exists)
function create_network() {
  docker network create $NETWORK || true
}

# Run Vector DB container (Qdrant Server)
function run_vectordb() {
  
  echo "Loading VectorDB Container..."

  docker run -d \
      --name $VECTORDB_CONTAINER\
      --cpuset-cpus=$VECTORDB_CPUS\
      --cpuset-mems=$VECTORDB_MEM_NODE\
      --network $NETWORK \
      -p 6333:6333 \
      -v $DATASET_DIR/qdrant_storage:/qdrant/storage \
      -v $(pwd)/$OUT:/app/out \
      $VECTORDB_IMAGE
}

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

function wait_for_embedding_ready() {
  echo "Waiting for Embedding Container to be ready..."
  URL="http://"${GPU_SERVER_IP}":5003/status"
  DATA='{"status":"status"}'

  while true; do
    # Send a POST request to /status
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X GET -H "Content-Type: application/json" -d "$DATA" $URL)
    
    if [ "$RESPONSE" -eq 200 ]; then
      echo "Embedding Container is ready."
      break
    else
      echo "Waiting... (HTTP Status: $RESPONSE)"
      sleep 1
    fi
  done
}

# Run Load Generator
function run_load_gen() {

  docker run -d \
      --name $LOADGEN_CONTAINER \
      --cpuset-cpus=$LOADGEN_CPUS \
      --cpuset-mems=$LOADGEN_MEM_NODE\
      --network $NETWORK \
      -v $DATASET_DIR/NQ_default_embedded_question_7830:/app/loadgen_dataset \
      $LOADGEN_IMAGE python load_generator.py \
                            --dataset-dir='/app/loadgen_dataset' \
                            --collection-name='wiki_passages' \
                            --target-rps=$LOADGEN_RPS \
                            --requests-count=$LOADGEN_QUERY_COUNT

}

# Run Question Container (Request Generator)
function run_question() {

  echo "Question Container Starts"

  # pcm
  PCM_LOG=$OUT/pcm-memory.log
  sudo $PCM_PATH/build/bin/pcm-memory > $PCM_LOG 2>&1 &
  PCM_PID=$!

# Do not use -d. docker stops after sending & reponding all queries
  docker run -it \
      --name $QUESTION_CONTAINER \
      --cpuset-cpus=$QUESTION_CPUS \
      --cpuset-mems=$QUESTION_MEM_NODE \
      --network $NETWORK \
      -p 5002:5002 \
      -p 6000:6000 \
      -v $(pwd)/$OUT:/app/out \
      -v $DATASET_DIR/NQ_default_question_7830:/app/NQ_default_question_7830 \
      $QUESTION_IMAGE python question_server_ttft.py \
          --question-dir /app/NQ_default_question_7830\
          --target-qps $REQGEN_RPS \
          --query-count $REQGEN_QUERY_COUNT \
          --gpu-server-ip=$GPU_SERVER_IP
  echo "Question Container Stops"

  # pcm
  echo "Stopping pcm-memory..."
  sudo kill $PCM_PID
  wait $PCM_PID 2>/dev/null || true
  echo "pcm-memory logs are saved in $PCM_LOG"
}

function summary() {

  echo "Logging..."

  docker logs $VECTORDB_CONTAINER &> "$VECTORDB_LOG" 2>&1 &
  docker logs $QUESTION_CONTAINER &> "$QUESTION_LOG" 2>&1 &
  docker logs $LOADGEN_CONTAINER &> "$LOADGEN_LOG" 2>&1 &

  docker stop $LOADGEN_CONTAINER
  docker rm $LOADGEN_CONTAINER

  # pcm_summary
  python pcm_cxl_node0.py --log-file-path="$PCM_LOG" --output-csv-path="$OUT/pcm_cxl_summary.csv"

  RPS_SUM=$(echo "$LOADGEN_RPS + $REQGEN_RPS" | bc)

  # result dir
  RESULTS_DIR="$RESULTS/$RPS_SUM"
  mkdir -p $RESULTS_DIR

  num_this_run=$(($(ls $RESULTS_DIR | grep -Eo [0-9]+ | sort -rn | head -n 1) + 1))

  RESULTS_DIR="$RESULTS/$RPS_SUM/$num_this_run"
  mkdir -p $RESULTS_DIR


  echo "Moving logs..."

  [ "$(ls -A $OUT)" ] && sudo mv $OUT/* $RESULTS_DIR
}

###########################################################################
#########################        EXECUTION        #########################
###########################################################################

for rps_test in ${RPS_TEST_POOL[@]}; do
  LOADGEN_RPS=$rps_test

  echo 'VECTORDB_CPUS='$VECTORDB_CPUS'
  QUESTION_CPUS='$QUESTION_CPUS'
  LOADGEN_CPUS='$LOADGEN_CPUS'
  LOADGEN_RPS='$LOADGEN_RPS'
  VECTORDB_MEM_NODE='$VECTORDB_MEM_NODE | tee $OUT/user.cfg

  sudo rm -rf $OUT 
  mkdir -p $OUT

  initialize

  run_vectordb

  wait_for_vectordb_ready

  wait_for_embedding_ready

  docker rm $QUESTION_CONTAINER

  if [ "$LOADGEN_RPS" -eq 0 ]; then
    echo "No load generator..."
  else
    echo "Running with load generator..."
    run_load_gen
  fi

  sleep 20

  run_question

  summary

  echo "Benchmark done. Please check Results."

done