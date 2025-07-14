
### Basic modules
import argparse
from datasets import load_from_disk, Dataset, load_dataset, Features, Value, Sequence
import time
from sentence_transformers import SentenceTransformer


def load_question(dir, split, num):
    print("Loading questions...")
    dataset = load_from_disk(dir)

    dataset_split = dataset[split]

    dataset_split = dataset_split.shuffle(seed=42)

    questions_list = []
    dataset_num = len(dataset_split)

    start = time.time()

    for i, item in enumerate(dataset_split):
        if i >= num: break
        question_id = item['id']
        # question = item['question']['text'] # use this when question is NQ_default
        question = item['input'] #use this when question is bioasq
        questions_list.append({"question_id": question_id, "question": question})
        if (i%1000 == 0 ): 
            end = time.time()
            print(f"Loading {i}/{dataset_num}: {end-start:.2f} seconds elapsed.", flush=True)
            start = end

    print("Loading questions done.")
    return questions_list

def store_question(questions_list, dir):
    print("Storing questions...")

    question_data = Dataset.from_list(questions_list)
    question_data.save_to_disk(f'{dir}_question_{len(questions_list)}')
    print("Storing questions done.")


def embedding_question(questions_list):
    print("Embedding questions...")
    model = SentenceTransformer("all-MiniLM-L6-v2")

    emb_list = []
    questions_num = len(questions_list)

    start = time.time()

    for i, item in enumerate(questions_list):
        question_id = item['question_id']
        question = item['question']
        embedded_question = model.encode(question).tolist()
        emb_list.append({"question_id": question_id, "question": question, "embedding": embedded_question})
        if (i%1000 == 0 ): 
            end = time.time()
            print(f"Embedding {i}/{questions_num}: {end-start:.2f} seconds elapsed.", flush=True)
            start = end
        

    print("Embedding questions done.")
    return emb_list


def store_embedding(emb_list, dir):
    print("Storing embedded questions...")
    embed_data = Dataset.from_list(emb_list)
    embed_data.save_to_disk(f'{dir}_embedded_question_{len(questions_list)}')

    print("Storing embedded questions done.")

def store_embedding_test(emb_list, dir):
    print("Storing embedded questions...")

    features = Features({
    	"question_id": Value("string"),
	    "question": Value("string"),
	    "embedding": Sequence(Value("float64")),
    })

    embed_data = Dataset.from_list(emb_list, features=features)
    embed_data.save_to_disk(f'{dir}_embedded_question_{len(emb_list)}')

    print("Storing embedded questions done.")


def argument_parser():
    parser = argparse.ArgumentParser()
    ### Dataset
    parser.add_argument("--dataset-dir", type=str, help="directory of preprocessed question data")
    parser.add_argument("--split", type=str, default="validation")
    parser.add_argument("--question-num", type=int, default=None)
    parser.add_argument("--store-question", action="store_true", default=False)
    parser.add_argument("--store-embedding", action="store_true", default=False)

    args = parser.parse_args()
    return args

if __name__ == "__main__":
    args = argument_parser()

    dataset_dir = args.dataset_dir
    split = args.split
    if args.question_num != None:
        num = args.question_num
    else:
        num = 1000000000 # max
    # Load question dataset
    questions_list = load_question(dataset_dir, split, num)

    # store question list
    if args.store_question:
        store_question(questions_list, dataset_dir)
    # print(questions_list)

    # embed questions
    emb_list = embedding_question(questions_list)

    # store embedding
    if args.store_embedding:
        store_embedding_test(emb_list, dataset_dir)

    # print(emb_list)

    
