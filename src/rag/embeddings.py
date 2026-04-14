"""Embedding utilities using sentence-transformers (all-MiniLM-L6-v2).

NOTE: sentence_transformers (and torch) are imported lazily inside
get_embedding_model() to avoid pulling ~2 GB of torch into memory
at application startup.  This is critical for Azure App Service
which kills containers that don't respond within the startup timeout.
"""
from __future__ import annotations

import logging
from typing import List

from config.settings import settings

logger = logging.getLogger(__name__)

_model = None


def get_embedding_model():
    """Lazy-load the SentenceTransformer model on first call."""
    global _model
    if _model is None:
        from sentence_transformers import SentenceTransformer
        logger.info(f"Loading embedding model: {settings.embedding_model}")
        _model = SentenceTransformer(settings.embedding_model)
    return _model


def embed_text(text: str) -> List[float]:
    """Embed a single text string into a 384-dim vector."""
    model = get_embedding_model()
    return model.encode(text, normalize_embeddings=True).tolist()


def embed_texts(texts: List[str], batch_size: int = 64) -> List[List[float]]:
    """Embed multiple texts in batch."""
    model = get_embedding_model()
    embeddings = model.encode(texts, batch_size=batch_size, normalize_embeddings=True)
    return embeddings.tolist()
