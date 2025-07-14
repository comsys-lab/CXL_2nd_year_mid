from datasets import load_dataset
import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--hf-dir", type=str, required=True, help="Huggingface dataset directory (e.g., jenhsia/ragged)")
    parser.add_argument("--subset", type=str, default=None, help="Subset or config name (e.g., pubmed). Optional.")
    parser.add_argument("--save-dir", type=str, required=True, help="Directory to save the dataset")
    args = parser.parse_args()

    # load dataset
    if args.subset:
        dataset = load_dataset(args.hf_dir, args.subset)
    else:
        dataset = load_dataset(args.hf_dir)

    # save dataset
    dataset.save_to_disk(args.save_dir)