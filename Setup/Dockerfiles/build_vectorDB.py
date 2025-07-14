import os
import time
import sys
from datasets import load_from_disk, concatenate_datasets
from qdrant_client import QdrantClient, models
from concurrent.futures import ThreadPoolExecutor
import argparse


def argument_parser():
    parser = argparse.ArgumentParser()
    ### Dataset
    parser.add_argument("--document-count", type=int, default=1000000000)
    parser.add_argument("--dataset-path", type=str, default="/app/wiki_test")
    parser.add_argument("--collection-name", type=str, default="wiki_passages")
    parser.add_argument("--host", type=str, default="163.152.48.209:6100")
    parser.add_argument("--port", type=int, default=6100)

    args = parser.parse_args()
    return args

args = argument_parser()

# 데이터셋 및 Qdrant 설정
base_dir = args.dataset_path
if not os.path.exists(base_dir):
    print(f"Dataset path '{base_dir}' does not exist.", flush=True)
    sys.exit(1)  # 데이터셋 경로가 없으면 프로그램 종료
embedding_dataset = load_from_disk(base_dir)
# embedding_dataset = embedding_dataset["data"]
if not embedding_dataset:
    print("The dataset is empty.", flush=True)
    sys.exit(1)
# Qdrant 클라이언트 설정
client = QdrantClient(
    host=args.host,
    port=args.port,
)
collection_name = args.collection_name

# 컬렉션 확인 및 생성
try:
    client.get_collection(collection_name=collection_name)
    print(f"Collection '{collection_name}' already exists.", flush=True)
except Exception:
    print(f"Collection '{collection_name}' does not exist. Creating now.", flush=True)
    client.create_collection(
        collection_name=collection_name,
        vectors_config=models.VectorParams(
            size=len(embedding_dataset[0]["embedding"]),  # 벡터 크기를 데이터에서 가져옴
            distance=models.Distance.COSINE,
        ),
    )

# 기존 데이터 개수 확인
try:
    existing_count = client.count(collection_name=collection_name, timeout=3000).count
except Exception as e:
    print(f"Error while fetching existing count: {e}", flush=True)
    sys.exit(1)  # 오류 발생 시 프로그램 종료

# 멀티스레드 업로드
batch_size = 10000
count = args.document_count
start_idx = existing_count
end_idx = min(len(embedding_dataset), start_idx + count)

if start_idx >= len(embedding_dataset):
    print("No more data to add.", flush=True)
else:
    print(f"Adding records from {start_idx} to {end_idx}.", flush=True)

    def upload_batch(start, end):
        batch_start_time = time.time()  # 배치 시작 시간 기록
        batch = embedding_dataset.select(range(start, end))
        points = [
            models.PointStruct(
                id=start + idx,
                vector=item["embedding"],
                payload={
                    "chunk_id": item["chunk_id"],
                    "document": item["document"],
                },
            )
            for idx, item in enumerate(batch)
        ]
        client.upload_points(collection_name=collection_name, points=points)
        batch_end_time = time.time()  # 배치 종료 시간 기록
        print(
            f"Uploaded batch from {start} to {end}. Batch upload time: {batch_end_time - batch_start_time:.2f} seconds.",
            flush=True
        )

    total_start_time = time.time()
    with ThreadPoolExecutor(max_workers=4) as executor:
        for start in range(start_idx, end_idx, batch_size):
            end = min(start + batch_size, end_idx)
            executor.submit(upload_batch, start, end)
    total_end_time = time.time()
    print(f"Total upload time: {total_end_time - total_start_time:.2f} seconds.", flush=True)

    # 업로드된 포인트 개수 확인
    try:
        total_points = client.count(collection_name=collection_name, timeout=3000).count
        print(f"Total points in collection '{collection_name}': {total_points}", flush=True)
    except Exception as e:
        print(f"Error while fetching total points: {e}", flush=True)
