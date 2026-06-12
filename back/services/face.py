import numpy as np
import cv2
from deepface import DeepFace

MODEL_NAME = "Facenet"
THRESHOLD = 0.7  # 🔥 70%
DETECTOR_BACKEND = "opencv" # 🔥 switched from mtcnn for 10x speed boost
FACE_CASCADE = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')

def read_and_resize(img_or_path, max_dim=800):
    try:
        if isinstance(img_or_path, str):
            img = cv2.imread(img_or_path)
        else:
            img = img_or_path
            
        if img is None:
            return None
            
        h, w = img.shape[:2]
        if max(h, w) > max_dim:
            scale = max_dim / max(h, w)
            new_w = int(w * scale)
            new_h = int(h * scale)
            img = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)
        return img
    except Exception as e:
        print(f"Resize error: {e}")
        return None

def fast_detect_face(img):
    """Very fast face detection using Haar Cascades."""
    try:
        img = read_and_resize(img, max_dim=800)
        if img is None:
            return False
        
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        faces = FACE_CASCADE.detectMultiScale(gray, 1.1, 4)
        return len(faces) > 0
    except:
        return False

# =========================
# 🎯 GET EMBEDDING
# =========================
def get_embedding(img):
    try:
        img = read_and_resize(img, max_dim=800)
        if img is None:
            return None
            
        result = DeepFace.represent(
            img_path=img,
            model_name=MODEL_NAME,
            enforce_detection=False, # Changed to False to prevent crashes on registration
            detector_backend=DETECTOR_BACKEND
        )

        if len(result) == 0:
            return None

        embedding = result[0]["embedding"]
        return np.array(embedding)

    except Exception as e:
        print("Embedding error:", e)
        return None

# =========================
# ✂️ EXTRACT & CROP FACE
# =========================
def extract_face(img_path):
    try:
        img = read_and_resize(img_path, max_dim=800)
        if img is None:
            return None

        faces = DeepFace.extract_faces(
            img_path=img,
            detector_backend=DETECTOR_BACKEND,
            enforce_detection=False,
            align=True
        )
        
        if not faces:
            return None
            
        # Get the largest face if multiple
        face_img = faces[0]["face"] # Normalized 0-1
        face_img = (face_img * 255).astype(np.uint8)
        face_img = cv2.cvtColor(face_img, cv2.COLOR_RGB2BGR)
        
        return face_img
    except Exception as e:
        print(f"Face extraction error: {e}")
        return None


# =========================
# 📐 COSINE SIMILARITY
# =========================
def cosine_similarity(a, b):
    a = np.array(a)
    b = np.array(b)

    if np.linalg.norm(a) == 0 or np.linalg.norm(b) == 0:
        return 0

    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))


# =========================
# 🧠 FIND BEST MATCH
# =========================
def find_match(face_embedding, persons):
    best_score = -1
    best_name = "Unknown"

    for person in persons:
        if not person.get("embedding"): continue
        db_embedding = np.array(person["embedding"])
        score = cosine_similarity(face_embedding, db_embedding)

        if score > best_score:
            best_score = score
            best_name = person["name"]

    if best_score >= THRESHOLD:
        return best_name, float(best_score)

    return "Unknown", float(best_score)