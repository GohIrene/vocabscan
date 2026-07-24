"""Adventure Treasures — the words a child has discovered in Home Adventure.

Deliberately its own collection rather than being derived from `scan_logs`.
A scan log records that recognition happened, in any mode, including teacher
projection and old test data; a treasure records that *this child* discovered
*this word* inside their own adventure and was rewarded for it. Deriving one
from the other would let unrelated history award treasures retroactively and
would make "is this a new word?" depend on data the adventure never created.

Duplicate protection is the unique index on (child_id, english_key), not an
application-level check: `discover()` reports whether the word was new by
whether the insert succeeded, so two rapid submissions cannot both be treated
as a first discovery.
"""

from datetime import datetime

from pymongo.errors import DuplicateKeyError, PyMongoError

from time_utils import local_day_start_utc


def discover(db, child_id, english_key, area_id=None):
    """Record a discovery. Returns True only the first time for this word.

    The return value is what decides new-word vs repeated-word rewards, so it
    has to come from the write itself rather than a preceding read.
    """
    if db is None or not child_id or not english_key:
        return False
    try:
        db.child_treasures.insert_one({
            "child_id": child_id,
            "english_key": english_key,
            # Which area was growing at the time — lets Phase 6 group the
            # album by where each word was found.
            "area_id": area_id,
            "discovered_at": datetime.utcnow(),
        })
        return True
    except DuplicateKeyError:
        return False
    except PyMongoError:
        return False


def has_discovered(db, child_id, english_key):
    if db is None:
        return False
    return db.child_treasures.find_one(
        {"child_id": child_id, "english_key": english_key}) is not None


def discovered_keys(db, child_id):
    """Every word this child has discovered, newest first."""
    if db is None:
        return []
    docs = db.child_treasures.find(
        {"child_id": child_id}).sort("discovered_at", -1)
    return [d["english_key"] for d in docs if d.get("english_key")]


def discovered_records(db, child_id):
    """Full treasure records, newest first — for the album in Phase 6."""
    if db is None:
        return []
    docs = db.child_treasures.find(
        {"child_id": child_id}).sort("discovered_at", -1)
    return [{
        "english_key": d.get("english_key"),
        "area_id": d.get("area_id"),
        "discovered_at": d.get("discovered_at"),
    } for d in docs if d.get("english_key")]


def count(db, child_id):
    if db is None:
        return 0
    return db.child_treasures.count_documents({"child_id": child_id})


def discovered_today(db, child_id):
    """How many words this child discovered today (local GMT+8 day).

    This is what drives the daily mission's "learn new words" goal, so the
    mission counts genuine first-time discoveries rather than re-scans.
    """
    if db is None:
        return 0
    return db.child_treasures.count_documents({
        "child_id": child_id,
        "discovered_at": {"$gte": local_day_start_utc()},
    })
