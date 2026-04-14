#!/bin/bash
set -e

echo "========================================="
echo "  AI-Powered ATS — Starting Up"
echo "========================================="

# ── Start the server IMMEDIATELY so Azure health probe passes ──
# Database initialization is handled by FastAPI's on_event("startup")
# Seeding (if needed) runs in background after server starts

echo "Starting application server..."
echo "========================================="

# Run seed check in background after a short delay
(
  sleep 10
  echo "[background] Checking if database seeding is needed..."
  python -c "
from src.database.session import SessionLocal
from src.database.models import Candidate
try:
    session = SessionLocal()
    count = session.query(Candidate).count()
    session.close()
    if count == 0:
        print('[background] Database empty — running seed...')
        import subprocess, sys
        subprocess.run([sys.executable, '-m', 'scripts.seed_database'], check=True)
        subprocess.run([sys.executable, '-m', 'scripts.compute_embeddings'], check=True)
        print('[background] Seeding complete!')
    else:
        print(f'[background] Database has {count} candidates — skipping seed.')
except Exception as e:
    print(f'[background] Seed check skipped (DB not ready yet): {e}')
" 2>&1 || true
) &

exec "$@"
