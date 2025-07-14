import asyncio
import argparse
import random
import multiprocessing
from qdrant_client import models, AsyncQdrantClient
from datasets import load_from_disk
import time
import os
import numpy as np

# Simulate poisson request intervals
def poisson_delay(p_lambda):
    return random.expovariate(p_lambda)  # Lambda값에 따른 지수 분포 간격

# Load dataset once and cache in memory
def load_dataset_once(dir, shared_list):
    dataset = load_from_disk(dir)
    dataset = dataset.shuffle(seed=42)
    embeddings = dataset["embedding"]  # 원하는 열 이름을 명시적으로 지정
    shared_list.extend(embeddings)  # Share data across processes
    print(f"Dataset loaded with {len(embeddings)} embeddings", flush=True)

# Perform random insert or query
async def generate_request(client, collection_name, embedding, request_times_queue):
    top_k = 5
    try:
        start = time.time()
        request_times_queue.put(start)  # Record request start time
        hits = await client.query_points(  # 비동기 작업은 await해야 함
            collection_name=collection_name,
            query=embedding,
            search_params=models.SearchParams(hnsw_ef=768, exact=False),
            limit=top_k,
            timeout=30000
        )
        end = time.time()
        print(f"Query completed in {end - start:.2f} seconds", flush=True)
    except Exception as e:
        print(f"Query failed: {e}", flush=True)

async def stress_test(client, collection_name, dataset, rate, req_count, request_times_queue, a=1.2):
    dataset_length = len(dataset)
    tasks = []  # Keep track of all tasks
    print(f"Starting stress test with {req_count} requests at rate {rate} RPS", flush=True)
    for i in range(req_count):

        delay = random.expovariate(rate)
        await asyncio.sleep(delay)
        index = np.random.zipf(a) % dataset_length

        embedding = dataset[index]  
        print(f"Sending request {index} with delay {delay:.2f}", flush=True)
        # embedding = dataset[i % dataset_length] # dataset[i % dataset_length]
        tasks.append(asyncio.create_task(generate_request(client, collection_name, embedding, request_times_queue)))
    await asyncio.gather(*tasks)
    print(f"Completed stress test with {req_count} requests", flush=True)

async def main_process(collection_name: str, dataset, rate: float, req_count: int, request_times_queue):
    print(f"Starting main process with collection: {collection_name}", flush=True)
    client = AsyncQdrantClient(url="172.26.0.1", port=6333)
    try:
        await client.get_collection(collection_name=collection_name)
        print(f"Collection '{collection_name}' checked successfully.", flush=True)
    except Exception as e:
        print(f"Collection check failed: {e}", flush=True)
        return

    # Start stress test
    await stress_test(client, collection_name, dataset, rate, req_count, request_times_queue)

def start_event_loop(collection_name, dataset, rate, req_count, request_times_queue):
    asyncio.run(main_process(collection_name, dataset, rate, req_count, request_times_queue))

def argument_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset-dir", type=str, required=True, help="Directory of preprocessed question data")
    parser.add_argument("--collection-name", type=str, required=True, help="Target collection name")
    parser.add_argument("--target-rps", type=float, required=True, help="Target requests per second (lambda)")
    parser.add_argument("--requests-count", type=int, required=True, help="Number of requests to send")
    return parser.parse_args()

if __name__ == "__main__":
    args = argument_parser()

    cpu_count = os.cpu_count()
    print(f"Using {cpu_count} processes", flush=True)

    manager = multiprocessing.Manager()
    shared_embeddings = manager.list()  # Shared list for dataset
    request_times_queue = multiprocessing.Queue()  # Shared queue for request start times

    # Load dataset once
    print("Loading dataset into shared memory...", flush=True)
    load_dataset_once(args.dataset_dir, shared_embeddings)

    processes = []
    for i in range(cpu_count):
        p = multiprocessing.Process(target=start_event_loop, args=(
            args.collection_name,
            shared_embeddings,  # Pass shared embeddings
            args.target_rps / cpu_count,  # Divide RPS across processes
            args.requests_count // cpu_count,  # Divide request count across processes
            request_times_queue  # Shared request times queue
        ))
        print(f"Starting process {i}", flush=True)
        p.start()
        processes.append(p)

    for i, p in enumerate(processes):
        p.join()
        print(f"Process {i} completed", flush=True)
        request_times_queue.put("DONE")  # 프로세스 종료 신호 추가

    # Queue 비우기 및 종료 대기
    print("Waiting for all queue data to be processed...", flush=True)
    done_count = 0
    request_times = []
    
    while done_count < cpu_count:
        data = request_times_queue.get()
        if data == "DONE":
            done_count += 1
        else:
            request_times.append(data)

    # Analyze Actual Target RPS and Achieved RPS
    request_times = sorted(request_times)
    total_requests = len(request_times)
    if total_requests > 1:
        total_duration = request_times[-1] - request_times[0]
        actual_target_rps = args.target_rps
        achieved_rps = total_requests / total_duration if total_duration > 0 else 0
        print(f"Actual Target RPS: {actual_target_rps:.2f} requests/second", flush=True)
        print(f"Achieved RPS: {achieved_rps:.2f} requests/second", flush=True)
    else:
        print("Not enough requests to calculate RPS", flush=True)
