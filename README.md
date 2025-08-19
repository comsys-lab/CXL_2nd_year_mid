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

### SW configuration

- OS: Ubuntu 22.04.4 LTS (Jammy Jellyfish)
- Kernel: Linux 6.12.0
- Python: 3.11.7
- Docker: 27.5.1

### Prerequisite

- pip
- wget
- curl
- Python packages:
    - pandas
    - numpy
    - matplotlib
    - datasets
    - transformers
    - sentence_transformers

### Git clone HMSDK, Qdrant

Git clone modified qdrant sourcecode in CXL_2nd_year_mid/Setup directory.

- `git clone https://github.com/comsys-lab/CXL_2nd_year_mid`
- `cd Setup`
- `git clone https://github.com/comsys-lab/qdrant`

### Download Dataset

- Download preprocessed common crawl from hugging face
    
    ```bash
    python3 download_huggingface.py --hf-dir="youkioh/c4_100gb_preprocessed" --save-dir="../Data/c4_100gb_preprocessed"
    ```
    
- Download Google NQ development dataset from hugging face
    
    ```bash
    python3 download_huggingface.py --hf-dir="google-research-datasets/natural_questions" --save-dir="../Data/NQ_default"
    ```
    

### Download LLM & Embedding Model

- Download Llama3-ChatQA-1.5-8B
    
    ```bash
    python3 download_huggingface.py --llm "nvidia/Llama3-ChatQA-1.5-8B" --save-dir="../Data/Llama3-ChatQA-1.5-8B"
    ```
    
- Download all-MiniLM-L6-v2
    
    ```bash
    python3 download_huggingface.py --embedding-model "all-MiniLM-L6-v2" --save-dir="../Data/all-MiniLM-L6-v2"
    ```
    

### Build Docker Images

- Build base docker images
    
    ```bash
    cd Setup/Dockerfiles
    docker build -f Dockerfile.preprocess -t preprocessing_image . 
    docker build -f Dockerfile.reqgen -t reqgen_image .
    docker build -f Dockerfile.loadgen -t loadgen_image .
    ```
    
- Build qdrant docker images
    
    ```bash
    cd Setup/Qdrant
    docker build . --tag=qdrant/qdrant_address
    ```
    

### Preprocess Dataset

- Preprocess Google NQ dataset
    - change DATASET_DIR in the script to the directory of downloaded data (…./Data)
    
    ```bash
    bash question_to_embedding.sh
    ```
    

### Build VectorDB

- change DATASET_DIR in the script to the directory of downloaded data (takes about 4~5 hours)

```bash
bash build_vectorDB.sh
```

### Build Custom Kernel

- Git clone modified HMSDK source code in HMSDK_2nd_year_mid/Setup
- `git clone https://github.com/comsys-lab/HMSDK_CXL_Private`

## Experiment Setup for GPU Server

### HW configuration

| **CPU** | 2× Intel Xeon 4410Y (Sapphire Rapids) @2.5 GHz, 12 cores |
| --- | --- |
|  | 30 MiB LLC per CPU, Hyper-Threading Enabled |
| **Memory** | Socket 0: 2× 64 GB DDR5-4800 MT/s, Total 128 GB |
|  | Socket 1: 2× 64 GB DDR5-4800 MT/s, Total 128 GB |
| **GPU** | 2x NVIDIA GeForce RTX 4090 |

### SW configuration

- OS: Ubuntu 22.04.4 LTS (Jammy Jellyfish)
- Kernel: Linux 6.12.0
- Python: 3.11.7
- CUDA: 12.2
- Docker: 27.5.1

### Build Docker Images

```bash
docker build -f Dockerfile.embedding -t embedding_image .
docker build -f Dockerfile.llm -t llm_inference_image .
```

### Run LLM and Embedding model server

- Run embedding and LLM in GPU server
    
    ```bash
    bash run_embedding.sh
    bash run_llm.sh
    ```
    
    - you need to authorize in huggingface to use “Llama3-ChatQA-1.5-8B” model

## Launch Experiments

### Hypothesis 1

- Start experiment shell script
    
    ```bash
    bash run_all.sh
    ```
    

### Hypothesis 2

- Start experiment shell script
    
    ```bash
    bash Qdrant_Local_address.sh
    ```
    
- Analyze address trace
    
    ```bash
    python3 address_count_analysis.py --vectordb-file-path=<vectorDB_container.log file path> --query-limit=10000 --csv-output-file="access_count_sorted.csv"
    
    python3 gen_cdf_plot.py --csv-file="access_count_sorted.csv"
    
    python3 hot_page_analysis.py --csv-file="access_count_sorted.csv" --access-threshold=200
    ```

## Launch Evaluation

### Prerequisite

- Change QDRANT_DATASET_DIR, EMBEDDED_QUESTION_DIR, QUESTION_DIR in sh to own directory
- Change PEBS_DIR in sh to own directory
- Compile reordering_agent.c
    
    ```bash
    cd HMSDK_CXL/pebs_userspace
    gcc -o reordering_agent reordering_agent.c -lcurl
    ```
    
- Compile pebs_userspace.c
    
    ```bash
    cd HMSDK_CXL/pebs_userspace
    gcc -o pebs_userspace pebs_userspace.c
    ```
    

### Baseline

- Start experiment shell script
    
    ```bash
    bash Baseline.sh
    ```
    

### AutoNUMA

- Change kernel to 6.6.0-hmsdk 2.0
- Start experiment shell script
    
    ```bash
    bash AutoNUMA.sh
    ```
    

### HMSDK

- Start experiment shell script
    
    ```bash
    bash HMSDK.sh
    ```
    

### Bauhaus

- Start experiment shell script