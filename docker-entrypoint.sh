#!/bin/bash
set -e

echo "========================================="
echo "  AI-Powered ATS — Starting Up"
echo "========================================="

# ── Wait for PostgreSQL (lightweight check, no heavy imports) ──
echo "[1/2] Waiting for database..."
MAX_RETRIES=30
RETRY=0
until python -c "
import os, socket
from urllib.parse import urlparse
url = urlparse(os.environ.get('DATABASE_URL', 'postgresql://postgres:postgres@db:5432/ats_db'))
host = url.hostname or 'db'
port = url.port or 5432
s = socket.create_connection((host, port), timeout=3)
s.close()
print(f'Database reachable at {host}:{port}')
" 2>/dev/null; do
    RETRY=$((RETRY+1))
    if [ $RETRY -ge $MAX_RETRIES ]; then
        echo "ERROR: Database not reachable after $MAX_RETRIES attempts"
        exit 1
    fi
    echo "  Waiting for DB... ($RETRY/$MAX_RETRIES)"
    sleep 2
done

# ── Init schema + seed in ONE Python process (avoids 3x cold starts) ──
echo "[2/2] Initializing database..."
python -c "
from sqlalchemy import text
from src.database.session import engine, SessionLocal
from src.database.models import Base, Candidate

# pgvector extension + schema
with engine.connect() as conn:
    conn.execute(text('CREATE EXTENSION IF NOT EXISTS vector'))
    conn.commit()
Base.metadata.create_all(bind=engine)
print('  Schema ready!')

# Check if seeding is needed
session = SessionLocal()
count = session.query(Candidate).count()
session.close()
if count == 0:
    print('  Database empty — running seed...')
    import subprocess, sys
    subprocess.run([sys.executable, '-m', 'scripts.seed_database'], check=True)
    subprocess.run([sys.executable, '-m', 'scripts.compute_embeddings'], check=True)
    print('  Seeding complete!')
else:
    print(f'  Database has {count} candidates — skipping seed.')
"

echo "========================================="
echo "  Starting application server..."
echo "========================================="

exec "$@"
