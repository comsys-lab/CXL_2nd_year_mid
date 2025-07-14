import torch
from transformers import AutoModel, AutoTokenizer

def load_local_model(model_dir):
    """로컬 디렉토리에서 모델과 토크나이저를 로드합니다."""
    try:
        print(f"Loading model from: {model_dir}")
        
        # 토크나이저 로드
        tokenizer = AutoTokenizer.from_pretrained(
            model_dir,
            local_files_only=True
        )
        
        # 모델 로드
        model = AutoModel.from_pretrained(
            model_dir,
            local_files_only=True,
            torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32
        )
        
        print("✅ Model and tokenizer loaded successfully!")
        print(f"Model type: {type(model).__name__}")
        print(f"Tokenizer type: {type(tokenizer).__name__}")
        
        return model, tokenizer
        
    except Exception as e:
        print(f"❌ Error loading model: {e}")
        return None, None

def test_model(model, tokenizer):
    """모델과 토크나이저가 제대로 작동하는지 테스트합니다."""
    try:
        # 간단한 텍스트로 테스트
        test_text = "Hello, how are you?"
        
        # 토큰화
        inputs = tokenizer(test_text, return_tensors="pt")
        print(f"Input tokens: {inputs}")
        
        # 모델 추론 (간단한 forward pass)
        with torch.no_grad():
            outputs = model(**inputs)
        
        print(f"Output shape: {outputs.last_hidden_state.shape}")
        print("✅ Model inference test passed!")
        
    except Exception as e:
        print(f"❌ Error during model test: {e}")

if __name__ == "__main__":
    # 로컬 모델 디렉토리 경로
    model_dir = "../Data/Model"  # 다운로드한 모델이 저장된 디렉토리
    
    # 모델과 토크나이저 로드
    model, tokenizer = load_local_model(model_dir)
    
    if model is not None and tokenizer is not None:
        # 모델 테스트
        test_model(model, tokenizer)
    else:
        print("Failed to load model and tokenizer")