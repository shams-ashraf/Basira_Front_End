import json
import os
import sqlite3

import numpy as np

from .embedding import get_embedding
from .similarity import cosine_similarity


def _db_path():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "back", "basera.db"))


def load_person_embeddings(child_id):
    path = _db_path()
    if not os.path.exists(path):
        return []

    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    try:
        rows = conn.execute(
            "SELECT name, embedding_vector FROM persons WHERE child_id = ?",
            (child_id,),
        ).fetchall()
    finally:
        conn.close()

    persons = []
    for row in rows:
        if not row["embedding_vector"]:
            continue
        try:
            persons.append({"name": row["name"], "embedding": np.array(json.loads(row["embedding_vector"]))})
        except Exception:
            continue
    return persons


def compare_against_child(face_image, child_id):
    emb = get_embedding(face_image)
    if emb is None:
        return {"best_match": "Unknown", "best_score": 0.0, "similarity_scores": {}}

    scores = {}
    best_match = "Unknown"
    best_score = 0.0
    for person in load_person_embeddings(child_id):
        score = float(cosine_similarity(emb, person["embedding"]))
        scores[person["name"]] = round(score, 4)
        if score > best_score:
            best_score = score
            best_match = person["name"]
    scores["Unknown"] = round(max(0.0, 1.0 - best_score), 4)
    return {"best_match": best_match, "best_score": round(best_score, 4), "similarity_scores": scores}
