import importlib

dependencies = [
    "fastapi",
    "uvicorn",
    "websockets",
    "ultralytics",
    "transformers",
    "torch",
    "safetensors",
    "vosk",
    "pyttsx3",
    "numpy",
    "cv2",
    "PIL",
    "sqlalchemy",
    "pydantic",
    "multipart",
    "deepface",
    "tf_keras"
]

missing = []
for dep in dependencies:
    try:
        importlib.import_module(dep)
        print(f"OK: {dep} is installed")
    except ImportError:
        # Some packages have different import names
        try:
            if dep == "cv2": importlib.import_module("cv2")
            elif dep == "PIL": importlib.import_module("PIL")
            elif dep == "multipart": importlib.import_module("multipart")
            else: raise ImportError
            print(f"OK: {dep} is installed")
        except ImportError:
            print(f"ERROR: {dep} is NOT installed")
            missing.append(dep)

if missing:
    print(f"\nMissing libraries: {', '.join(missing)}")
else:
    print("\nAll libraries are installed!")
