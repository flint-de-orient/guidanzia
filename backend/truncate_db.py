"""Reset the Guidenzia database (MongoDB).

Empties all five collections while KEEPING their indexes and JSON Schema
validators intact (uses delete_many, not drop). This is the MongoDB equivalent
of the old SQLite "DELETE FROM every table + reset autoincrement" script.

Reads MONGO_URI / MONGO_DB from the project-root .env (same as the app), so it
always targets whichever database the backend is actually using.

Usage:
    python truncate_db.py            # empty every collection
    python truncate_db.py --drop     # DROP the whole database (indexes +
                                     # validators too) — use only for a full rebuild
"""
import os
import sys
from dotenv import load_dotenv
from pymongo import MongoClient

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '.env'))

MONGO_URI = os.getenv('MONGO_URI', 'mongodb://localhost:27017')
MONGO_DB = os.getenv('MONGO_DB', 'guidenzia')
COLLECTIONS = [
    'users',
    'user_session',
    'job_role_details',
    'onboarding_data',
    'career_recommendations',
]


def truncate_database(drop=False):
    client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
    try:
        client.admin.command('ping')
    except Exception as e:
        print(f"ERROR: cannot reach MongoDB at {MONGO_URI}: {e}")
        return

    db = client[MONGO_DB]

    if drop:
        client.drop_database(MONGO_DB)
        print(f"SUCCESS: dropped database '{MONGO_DB}' (collections, indexes and")
        print("         validators removed). Re-run the setup scripts to recreate.")
        client.close()
        return

    try:
        for name in COLLECTIONS:
            deleted = db[name].delete_many({}).deleted_count
            print(f"  cleared {name}: {deleted} document(s) removed")
        print(f"\nSUCCESS: Database '{MONGO_DB}' truncated.")
        print("- All collections emptied")
        print("- Indexes and JSON Schema validators preserved")
    except Exception as e:
        print(f"ERROR: Error truncating database: {e}")
    finally:
        client.close()


if __name__ == "__main__":
    truncate_database(drop='--drop' in sys.argv)
