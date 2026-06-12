import numpy as np
import cv2
from deepface import DeepFace


MODEL_NAME = "Facenet"
DETECTOR_BACKEND = "opencv"


def read_and_resize(img_or_path, max_dim=800):
    if isinstance(img_or_path, str):
        img = cv2.imread(img_or_path)
    else:
        img = img_or_path

    if img is None:
        return None

    h, w = img.shape[:2]
    if max(h, w) > max_dim:
        scale = max_dim / max(h, w)
        img = cv2.resize(img, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
    return img


def get_embedding(img):
    try:
        img = read_and_resize(img, max_dim=800)
        if img is None:
            return None

        result = DeepFace.represent(
            img_path=img,
            model_name=MODEL_NAME,
            enforce_detection=False,
            detector_backend=DETECTOR_BACKEND,
        )
        if not result:
            return None
        return np.array(result[0]["embedding"])
    except Exception:
        return None
