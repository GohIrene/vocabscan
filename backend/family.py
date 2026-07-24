"""Family Codes — how a child gets into Home Mode without a parent login.

A child types the family code, picks their face, and (if their parent set one)
types a 4-digit child PIN. That is the whole entry path: no username, no
parent password.

The code is a *standing* credential on the parent's user document, unlike a
Class Code which belongs to one live session and dies with it. The alphabet
deliberately matches Class Code's — same shape, same excluded ambiguous
characters, so a child who has typed one has already learned the other — but
it's redeclared here rather than imported, to keep Home Mode from depending
on the Class Code module.
"""

import random

from pymongo.errors import DuplicateKeyError, PyMongoError

import state

# No 0/O/1/I: a code gets read off a screen and typed by a young child, and
# those are the pairs they confuse. L is kept — with both 1 and I absent there
# is nothing left for it to be mistaken for. Character-for-character identical
# to class_sessions._CODE_ALPHABET, so the two kinds of code look alike.
FAMILY_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
FAMILY_CODE_LENGTH = 6

# Bounded so a pathologically unlucky (or exhausted) keyspace fails loudly
# instead of spinning forever inside a request.
_MAX_GENERATION_ATTEMPTS = 12


def normalise_code(raw):
    """Codes are stored and compared uppercase; children type them however."""
    return (raw or "").strip().upper().replace(" ", "").replace("-", "")


def generate_family_code():
    """A code no parent is currently using, or None if we couldn't find one."""
    for _ in range(_MAX_GENERATION_ATTEMPTS):
        code = "".join(
            random.choice(FAMILY_CODE_ALPHABET) for _ in range(FAMILY_CODE_LENGTH)
        )
        if state.db is None:
            return code
        try:
            if state.db.users.find_one({"family_code": code}) is None:
                return code
        except PyMongoError:
            return None
    return None


def ensure_family_code(user):
    """This parent's family code, creating and persisting one if they have none.

    Generated lazily on first read rather than back-filled by a migration:
    a code is only meaningful once a parent actually looks it up to share it,
    and this way accounts created before Family Codes existed heal themselves
    the first time the parent opens the screen.

    Returns None if a code could not be assigned.
    """
    existing = (user or {}).get("family_code")
    if existing:
        return existing

    user_id = (user or {}).get("user_id")
    if not user_id or state.db is None:
        return None

    for _ in range(_MAX_GENERATION_ATTEMPTS):
        code = generate_family_code()
        if code is None:
            return None
        try:
            # Only claim the code if this parent still has none — two tabs
            # hitting the screen at once must not end up with two codes.
            result = state.db.users.update_one(
                {"user_id": user_id,
                 "$or": [{"family_code": {"$exists": False}},
                         {"family_code": None}, {"family_code": ""}]},
                {"$set": {"family_code": code}},
            )
            if result.modified_count:
                return code
            # Lost the race (or nothing matched) — re-read whatever won.
            current = state.db.users.find_one({"user_id": user_id})
            if current and current.get("family_code"):
                return current["family_code"]
            return None
        except DuplicateKeyError:
            continue  # unique index caught a collision; roll another code
        except PyMongoError:
            return None
    return None


def set_new_family_code(user_id):
    """Replace a parent's code with a fresh one, invalidating the old one."""
    if state.db is None:
        return None
    for _ in range(_MAX_GENERATION_ATTEMPTS):
        code = generate_family_code()
        if code is None:
            return None
        try:
            state.db.users.update_one(
                {"user_id": user_id}, {"$set": {"family_code": code}}
            )
            return code
        except DuplicateKeyError:
            continue
        except PyMongoError:
            return None
    return None


def find_parent_by_code(code):
    """The parent account owning [code], or None. Parents only, by design."""
    if state.db is None:
        return None
    normalised = normalise_code(code)
    if len(normalised) != FAMILY_CODE_LENGTH:
        return None
    try:
        return state.db.users.find_one(
            {"family_code": normalised, "role": "parent"}
        )
    except PyMongoError:
        return None
