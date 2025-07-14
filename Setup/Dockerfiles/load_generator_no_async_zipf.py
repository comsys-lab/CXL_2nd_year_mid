import argparse
from qdrant_client import models, QdrantClient
from datasets import load_from_disk
import time
import random
import numpy as np


# Load dataset once
def load_dataset(dir):
    dataset = load_from_disk(dir)
    dataset = dataset.shuffle(seed=42)
    return dataset["embedding"]  # embedding 열만 사용


# Perform query and collect chunk_id
def generate_request(client, collection_name, embedding, i):
    top_k = 5
    try:
        start = time.time()
        
        # 쿼리 요청
        hits_result = client.query_points(
            collection_name=collection_name,
            query=embedding,
            search_params=models.SearchParams(hnsw_ef=768, exact=False),
            limit=top_k,
            timeout=30000
        )
        
        hits = hits_result.points

        # chunk_id 추출
        chunk_ids = [hit.payload['chunk_id'] for hit in hits if 'chunk_id' in hit.payload]
        
        end = time.time()
        print(f"Query {i} completed in {end - start:.2f} seconds. Chunk IDs: {chunk_ids}", flush=True)
        return chunk_ids
    
    except Exception as e:
        print(f"Query failed: {e}", flush=True)
        return []


# 메인 실행
def main(collection_name, dataset, rate, req_count, a=1.2):
    client = QdrantClient(url="172.26.0.1", port=6333)

    try:
        client.get_collection(collection_name=collection_name)
        # print(f"Collection '{collection_name}' checked successfully.", flush=True)
    except Exception as e:
        print(f"Collection check failed: {e}", flush=True)
        return

    chunk_id_log = []

    print(f"Starting {req_count} queries at rate {rate} RPS...", flush=True)

    np.random.seed(42)
    dataset_length = len(dataset)
    for i in range(req_count):
        delay = random.expovariate(rate)
        time.sleep(delay)
        index = np.random.zipf(a) % dataset_length
        embedding = dataset[index]    
        print(f"Sending request {i} with delay: {delay:.2f}, index: {index}", flush=True)
        chunk_ids = generate_request(client, collection_name, embedding, i)
        chunk_id_log.append(chunk_ids)

    print("\nQuery Log Results:")
    for i, chunk_ids in enumerate(chunk_id_log):
        print(f"Query {i}: Chunk IDs: {chunk_ids}")


# Argument parser
def argument_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset-dir", type=str, required=True, help="Directory of preprocessed question data")
    parser.add_argument("--collection-name", type=str, required=True, help="Target collection name")
    parser.add_argument("--target-rps", type=float, required=True, help="Target requests per second (lambda)")
    parser.add_argument("--requests-count", type=int, required=True, help="Number of requests to send")
    parser.add_argument("--zipfian-alpha", type=float, default=1.2, help="Zipfian distribution parameter")
    return parser.parse_args()


if __name__ == "__main__":
    args = argument_parser()

    # print("Loading dataset...", flush=True)
    dataset = load_dataset(args.dataset_dir)

    main(args.collection_name, dataset, args.target_rps, args.requests_count, args.zipfian_alpha)
