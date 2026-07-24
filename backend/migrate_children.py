"""Back-fill Home Adventure fields onto child profiles created before them.

Run once from the backend directory:

    python migrate_children.py            # apply
    python migrate_children.py --dry-run  # report only, write nothing

Every field is written with its own `$exists: false` filter, so the migration
is idempotent at field granularity: re-running it can only ever fill a gap,
never overwrite a value a child has since earned. That matters because this
script may well be run again after children have real XP and streaks.

Deliberately does NOT derive anything from scan_logs / quiz_logs /
speech_logs. Existing profiles were test data, so every child starts Home
Adventure at zero; the logs are left untouched for report and revision
compatibility.
"""

import sys

from pymongo.errors import PyMongoError

import state
from child_profile import migration_defaults


def _plan():
    """(field, value) pairs to back-fill, top-level fields only.

    `streak` is set as a whole object rather than by dotted sub-key: a
    document with no `streak` at all is the case being fixed, and a partial
    one is already normalised on read by apply_child_defaults.
    """
    return sorted(migration_defaults().items())


def migrate(dry_run=False):
    if state.db is None:
        print("MongoDB unavailable — nothing done.")
        return 1

    children = state.db.children
    try:
        total = children.count_documents({})
    except PyMongoError as e:
        print(f"Could not read children: {e}")
        return 1

    print(f"{total} child profile(s) in the database.")
    print("DRY RUN — no writes will be made.\n" if dry_run else "")

    touched = 0
    for field, value in _plan():
        missing = {field: {"$exists": False}}
        try:
            count = children.count_documents(missing)
            if count == 0:
                print(f"  {field:24} up to date")
                continue
            if not dry_run:
                children.update_many(missing, {"$set": {field: value}})
            verb = "would set" if dry_run else "set"
            print(f"  {field:24} {verb} on {count} profile(s) -> {value!r}")
            touched += count
        except PyMongoError as e:
            print(f"  {field:24} FAILED: {e}")
            return 1

    if touched == 0:
        print("\nNothing to migrate — every profile already has these fields.")
    elif dry_run:
        print(f"\n{touched} field write(s) pending. Re-run without --dry-run.")
    else:
        print(f"\nDone: {touched} field write(s).")

    # child_pin_hash is intentionally absent from the plan: no PIN is the
    # correct state for an existing child, and it must stay *missing* rather
    # than null so "has a PIN" remains a plain existence check.
    return 0


if __name__ == "__main__":
    sys.exit(migrate(dry_run="--dry-run" in sys.argv))
