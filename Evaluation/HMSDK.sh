#!/bin/bash

set -x

###########################################################################
#########################      CONFIGURATIONS     #########################
###########################################################################

### Unused memory config
LOCAL_MEM_SIZE=$1
CXL_MEM_SIZE_2=$2
UNUSED_MEM_DIR=/home/new_cloud_cxl/unused_memory

### Loadgen config
# RPS_TEST_POOL=(0 2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32 34 36 38 40 42 44 46 48 50 52 54 56 58 60 62 64 66 68 70 72 74)
RPS_TEST_POOL=(19.2)
LOADGEN_REQ_COUNT=1000000
HISGEN_REQ_COUNT=1000000

### Question Generation Config
TARGET_RPS=0.5
QUERY_COUNT=1000 #7830 is max for NQ development dataset

### Resource Config
VECTORDB_CPUS=$(numactl -H | grep "node 0 cpus:" | sed 's/^node 0 cpus: //' | tr ' ' ',')
VECTORDB_MEM_NODE=0,2

# Define CPU ranges for QUESTION_CPUS
QUESTION_CPUS=$(seq 16 23 | tr '\n' ',')$(seq 48 55 | tr '\n' ',' | sed 's/,$//')
QUESTION_MEM_NODE=1

# Define CPU ranges for LOADGEN_CPUS
LOADGEN_CPUS=$(seq 24 31 | tr '\n' ',')$(seq 56 63 | tr '\n' ',' | sed 's/,$//')
LOADGEN_MEM_NODE=1

### Container & Image NAME
VECTORDB_CONTAINER=vectorDB_container
QUESTION_CONTAINER=question_container
LOADGEN_CONTAINER=loadgen_container
VECTORDB_IMAGE=qdrant/qdrant_reorder_addr
QUESTION_IMAGE=question_image
LOADGEN_IMAGE=loadgen_image
NETWORK=my_network

### Output ###
OUT=out #temporal output resides here
RESULTS=$(date '+%y%m%d')_HMSDK_${LOCAL_MEM_SIZE}_${CXL_MEM_SIZE_2}
VECTORDB_LOG=$OUT/$VECTORDB_CONTAINER.log
QUESTION_LOG=$OUT/$QUESTION_CONTAINER.log
LOADGEN_LOG=$OUT/$LOADGEN_CONTAINER.log

### PEBS ###
HISTORY_INTERVAL=5
SAMPLING_INTERVAL=15000
PEBS_DIR=/home/new_cloud_cxl/extra_space_2TB/CXL_2nd_year_mid_old/Setup/HMSDK_CXL/pebs_userspace
PEBS_BIN="$PEBS_DIR/pebs_userspace"
REORDER_AGENT="$PEBS_DIR/reordering_agent"

### Prediction
PSI=15 # original: 3 # test 1: 10(60%, 22,489,210) # test 2: 15 (67%, 17,430,676 / 71%, 17,361,631 / 68% 17,224,939) # test 3: 20(77%, 15,633,087 / 80%, 16,167,031 / 77% 14,552,348)
DISTANCE=100 # original: 100(32%, 14,910,100) # test 1: 1000(28%, 14,431,873) # test 2: 10(30%, 24,359,041)
DEPTH=100 # original: 100 # test 1: 100,1000(16%, 51,485,762)

## perf
STAT_EVENTS=instructions,instructions:u,instructions:k,cycles:u,cycles:k,syscalls:sys_enter_sched_yield,syscalls:sys_enter_futex,syscalls:sys_enter_futex_waitv,sched:sched_switch,sched:sched_waking,mem_load_retired.l3_miss,mem_load_l3_miss_retired.local_dram,lock:contention_begin,lock:contention_end

### HMSDK 3.0
HMSDK_PATH=/home/new_cloud_cxl/hmsdk3.0
DAMO_YAML=$HMSDK_PATH/hmsdk_test.yaml

### Directory Setting
### c4 & NQ dataset (all-miniLM-L6-v2)
QDRANT_DATASET_DIR=/home/new_cloud_cxl/extra_space_2TB/binbin/test/qdrant_server_c4
EMBEDDED_QUESTION_DIR=/home/new_cloud_cxl/extra_space_2TB/binbin/test/NQ_default_embedded_question_7830
QUESTION_DIR=/home/new_cloud_cxl/extra_space_2TB/binbin/test/NQ_default_question_7830

### pubmed & bioasq dataset (all-miniLM-L6-v2)
# QDRANT_DATASET_DIR=/home/new_cloud_cxl/binbin/qdrant_server_PubMed_new
# EMBEDDED_QUESTION_DIR=/home/new_cloud_cxl/binbin/PubMed_miniLM/bioasq_embedded_question_3837
# QUESTION_DIR=/home/new_cloud_cxl/binbin/PubMed_miniLM/bioasq_question_3837

### c4 & NQ dataset (bge-base-en-v1.5) & need 3KB kernel, Embedding model change in GPU
# QDRANT_DATASET_DIR=/home/new_cloud_cxl/binbin/qdrant_server_c4_bge_new
# EMBEDDED_QUESTION_DIR=/home/new_cloud_cxl/extra_space_2TB/binbin/test/NQ_default_bge_test_embedded_question_7830
# QUESTION_DIR=/home/new_cloud_cxl/extra_space_2TB/binbin/test/NQ_default_question_7830

### pubmed & bioasq dataset (bge-base-en-v1.5)  & need 3KB kernel, Embedding model change in GPU
# QDRANT_DATASET_DIR=/home/new_cloud_cxl/binbin/qdrant_server_PubMed_bge_new
# EMBEDDED_QUESTION_DIR=/home/new_cloud_cxl/binbin/PubMed_bge/bioasq_bge_embedded_question_3837
# QUESTION_DIR=/home/new_cloud_cxl/binbin/PubMed_miniLM/bioasq_question_3837

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

  docker run -d --privileged \
	  --name $VECTORDB_CONTAINER\
      --cpuset-cpus=$VECTORDB_CPUS\
      --cpuset-mems=$VECTORDB_MEM_NODE\
      --network $NETWORK \
      -p 6333:6333 \
      -v $QDRANT_DATASET_DIR:/qdrant/storage \
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
  URL="http://163.152.48.206:5003/status"
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

# Run Load Generator (Warm-up)
function run_warm_up() {
  sudo $(which damo) stop
  sleep 5

  # Extract cgroup where the server container resides
  DOCKER_ID_FULL=$(docker inspect $VECTORDB_CONTAINER -f '{{.Id}}')
  NEW_MEMCG_PATH=/system.slice/docker-${DOCKER_ID_FULL}.scope
  
  # Update memcg_path to point to the Docker container
  sed -i "s|memcg_path:.*|memcg_path: $NEW_MEMCG_PATH|" $DAMO_YAML

  # Track the server container only
  sudo $(which damo) start $DAMO_YAML
  sleep 5

  docker run -d --rm \
      --name $LOADGEN_CONTAINER \
      --cpuset-cpus=$LOADGEN_CPUS \
      --cpuset-mems=$LOADGEN_MEM_NODE\
      --network $NETWORK \
      -v $EMBEDDED_QUESTION_DIR:/app/loadgen_dataset \
      -v /home/new_cloud_cxl/extra_space_2TB/binbin/test/load_generator_zipf.py:/app/load_generator.py \
      $LOADGEN_IMAGE python load_generator.py \
                            --dataset-dir='/app/loadgen_dataset' \
                            --collection-name='wiki_passages' \
                            --target-rps=$LOADGEN_RPS \
                            --requests-count=$HISGEN_REQ_COUNT

}

# Run Load Generator
function run_load_gen() {

  docker run -d \
      --name $LOADGEN_CONTAINER \
      --cpuset-cpus=$LOADGEN_CPUS \
      --cpuset-mems=$LOADGEN_MEM_NODE\
      --network $NETWORK \
      -v $EMBEDDED_QUESTION_DIR:/app/loadgen_dataset \
      -v /home/new_cloud_cxl/extra_space_2TB/binbin/test/load_generator_zipf.py:/app/load_generator.py \
      $LOADGEN_IMAGE python load_generator.py \
                            --dataset-dir='/app/loadgen_dataset' \
                            --collection-name='wiki_passages' \
                            --target-rps=$LOADGEN_RPS \
                            --requests-count=$LOADGEN_REQ_COUNT

}

# Run Question Container (Request Generator)
function run_question() {


  echo "Question Container Starts"

  # pcm
  PCM_LOG="/home/new_cloud_cxl/extra_space_2TB/binbin/test/$OUT/pcm-memory.log"
  sudo /home/new_cloud_cxl/pcm/build/bin/pcm-memory > $PCM_LOG 2>&1 &
  PCM_PID=$!

  # Do not use -d. docker stops after sending & reponding all queries
  # sudo perf stat -C $VECTORDB_CPUS -e $STAT_EVENTS -d -o $OUT/stats.txt\
  sudo perf stat -C "$VECTORDB_CPUS" -M "TopdownL1" -o $OUT/tma.txt\
  docker run -it \
      --name $QUESTION_CONTAINER \
      --cpuset-cpus=$QUESTION_CPUS \
      --cpuset-mems=$QUESTION_MEM_NODE \
      --network $NETWORK \
      -p 5002:5002 \
      -p 6000:6000 \
      -v /home/new_cloud_cxl/extra_space_2TB/binbin/test/question_server_ttft_zipf.py:/app/question_server_ttft_zipf.py \
      -v $(pwd)/$OUT:/app/out \
	  -v $QUESTION_DIR:/app/question \
      $QUESTION_IMAGE python question_server_ttft_zipf.py \
          --question-dir /app/question\
          --target-qps $TARGET_RPS \
          --query-count $QUERY_COUNT
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
  sleep 5
  sudo $(which damo) status > $OUT/damo_status.log 2>&1
  sudo $(which damo) stop
  sleep 5
  # pcm_summary
  python pcm_cxl_node0.py --log-file-path="$PCM_LOG" --output-csv-path="$OUT/pcm_cxl_summary.csv"

  RPS_SUM=$(echo "$LOADGEN_RPS + $TARGET_RPS" | bc)

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
  LOADGEN_RPS=$(echo "$rps_test - 0.5" | bc)

  echo 'VECTORDB_CPUS='$VECTORDB_CPUS'
  QUESTION_CPUS='$QUESTION_CPUS'
  LOADGEN_CPUS='$LOADGEN_CPUS'
  LOADGEN_RPS='$LOADGEN_RPS'
  VECTORDB_MEM_NODE='$VECTORDB_MEM_NODE | tee $OUT/user.cfg

  sudo rm -rf $OUT # delete temp output folder
  mkdir -p $OUT # create temp output folder

  initialize
  create_network
  
  sudo $UNUSED_MEM_DIR/memory_small.sh $LOCAL_MEM_SIZE 0      
  sudo $UNUSED_MEM_DIR/memory_small.sh $CXL_MEM_SIZE_2 2 
#   sudo $UNUSED_MEM_DIR/memory_small.sh $CXL_MEM_SIZE_3 3
  sudo sysctl -w kernel.perf_cpu_time_max_percent=25
  sudo sysctl kernel.perf_event_max_sample_rate=100000
  sudo sysctl -w kernel.perf_cpu_time_max_percent=100
  
  run_vectordb
  
  sleep 5
  VECTORDB_CGROUP_ID=$(docker inspect --format '{{.Id}}' $VECTORDB_CONTAINER)
  VECTORDB_CGROUP_PATH="/sys/fs/cgroup/system.slice/docker-${VECTORDB_CGROUP_ID}.scope"
  vector_PID=$(ps -el | grep qdrant | awk '{print $4}')

  wait_for_vectordb_ready
  
  ### PEBS start
  sudo dmesg -C
  sudo dmesg -w &> "$OUT/dmesg_${HISTORY_INTERVAL}_$SAMPLING_INTERVAL.log" 2>&1 &
  DMESG_PID=$!

  # sudo "$PEBS_BIN" start $vector_PID $VECTORDB_CGROUP_PATH $HISTORY_INTERVAL

  # sudo "$PEBS_BIN" history_end $vector_PID $VECTORDB_CGROUP_PATH $SAMPLING_INTERVAL $PSI $DISTANCE $DEPTH

  if [ "$LOADGEN_RPS" -eq 0 ]; then
    echo "No warm_up..."
  else
    echo "Running with warm_up..."
    run_warm_up
  fi
  sleep 1000

  # loadgen end
  docker stop loadgen_container
  docker rm loadgen_container
  
# #   print reordering data
#   sudo "$PEBS_BIN" reordering_data $vector_PID $VECTORDB_CGROUP_PATH $SAMPLING_INTERVAL
  
# #   call API
#   sudo "$REORDER_AGENT"

  if [ "$LOADGEN_RPS" -eq 0 ]; then
    echo "No load generator..."
  else
    echo "Running with load generator..."
    run_load_gen
  fi
  sleep 10

  run_question

  # # PEBS end
  # sudo "$PEBS_BIN" end $vector_PID $VECTORDB_CGROUP_PATH $SAMPLING_INTERVAL

  sudo kill $DMESG_PID
  wait $DMESG_PID 2>/dev/null || true

  summary

  echo "Benchmark done. Please check Results."

done