import logging
from typing import List, Dict, Any

logger = logging.getLogger(__name__)

class VectorStoreStub:
    """
    A stub/mock implementation of a Vector Database for storing
    and retrieving embeddings of people, objects, and locations.
    
    In production, this would wrap Qdrant, Milvus, or FAISS.
    """
    def __init__(self):
        self.memory_db = []

    def add_embedding(self, entity_id: str, embedding: List[float], metadata: Dict[str, Any]):
        """Store an embedding with its metadata."""
        record = {
            "id": entity_id,
            "embedding": embedding,
            "metadata": metadata
        }
        self.memory_db.append(record)
        logger.info(f"Added embedding to memory for {entity_id}")

    def search(self, query_embedding: List[float], limit: int = 3) -> List[Dict[str, Any]]:
        """Search for similar embeddings. Stub returns empty for now."""
        logger.info(f"Searching vector store with limit {limit}")
        # To be implemented with cosine similarity / L2 distance
        return []

    def get_last_known_location(self, object_name: str) -> str:
        """Helper to find last known location of an object."""
        for record in reversed(self.memory_db):
            if record["metadata"].get("object_name") == object_name:
                return record["metadata"].get("location", "Unknown")
        return "Unknown"

# Global memory instance
memory = VectorStoreStub()
