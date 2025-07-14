# CXL_2nd_year_reproduce


## Experiment Setup for CPU server

### HW configuration

---

| **CPU** | **2× Intel Xeon 6426Y** (Sapphire Rapids) @2.5 GHz, **16 cores** |
| --- | --- |
|  | 37.5 MiB LLC per CPU, Hyper-Threading Enabled |
| **Memory** | Socket 0: 4× 32 GB DDR5-4000 MT/s, **Total 128 GB** |
|  | Socket 1: 4× 32 GB DDR5-4000 MT/s, **Total 128 GB** |
|  | 2 x 96 GB CXL Expander: PCIe 5.0 ×8, **Total 192 GB** |
| **Motherboard** | Supporting CXL 1.1, CXL Type 3 Legacy Enabled |

### Prerequisite

- python 3.11.7
    - pandas
    - numpy
    - matplotlib
- pip
- docker
- wget
- curl

### Build Docker Images

- Build base docker images
    
    ```bash
    cd Setup/Dockerfiles
    docker build -f Dockerfile.preprocess -t preprocessing_image . 
    docker build -f Dockerfile.reqgen -t reqgen_image .
    docker build -f Dockerfile.loadgen -t loadgen_image .
    docker pull qdrant/qdrant
    ```
    
- Build custom qdrant docker images
    
    ```bash
    cd Setup/qdrant
    docker build . --tag=qdrant/qdrant_address
    ```
    

### Download Data

- Download preprocessed common crawl from hugging face
    
    ```bash
    python download_huggingface.py --hf-dir="youkioh/c4_100gb_preprocessed" --save-dir="../Data/c4_100gb_preprocessed"
    ```
    
- Download Google NQ development dataset from hugging face
    
    ```bash
    python download_huggingface.py --hf-dir="google-research-datasets/natural_questions" --save-dir="../Data/NQ_default"
    ```
    
- Preprocess Google NQ dataset
    - change DATASET_DIR in the script to the directory of downloaded data (…./Data)
    
    ```bash
    bash question_to_embedding.sh
    ```
    

### Build VectorDB

- change DATASET_DIR in the script to the directory of downloaded data (takes about 1~2 days)

```bash
bash build_vectorDB.sh
```

### Git Clone HMSDK, Qdrant

- git clone HMDSK and Qdrant from

### Build Custom Kernel

- Follow README.md in Setup/HMSDK_CXL

## Experiment Setup for GPU Server

### HW configuration

| **CPU** | 2× Intel Xeon 4410Y (Sapphire Rapids) @2.5 GHz, 12 cores |
| --- | --- |
|  | 30 MiB LLC per CPU, Hyper-Threading Enabled |
| **Memory** | Socket 0: 2× 64 GB DDR5-4800 MT/s, Total 128 GB |
|  | Socket 1: 2× 64 GB DDR5-4800 MT/s, Total 128 GB |
| **GPU** | 2x NVIDIA GeForce RTX 4090 |

### Build Docker Images

```bash
docker build -f Dockerfile.embedding -t embedding_image .
docker build -f Dockerfile.llm -t llm_inference_image .
```