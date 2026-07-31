"""Shape of a child profile: new-profile defaults, and safe reads of old ones.

Child documents predate Home Adventure mode, so most stored profiles are
missing every field below. Two separate mechanisms cover that, and they are
deliberately not the same code path:

  * `new_child_fields()` — what gets written when a profile is created.
  * `migration_defaults()` — what `migrate_children.py` back-fills, once,
    guarded per field by `$exists: false` so a re-run can never flatten real
    progress.
  * `apply_child_defaults()` — a *read-only* fallback applied when serialising
    a profile to JSON. It returns a new dict and never writes, so a GET can
    never mutate stored data. This is what lets legacy profiles load safely
    even if the migration has not been run yet.

Both writers and the reader draw their values from `_DEFAULTS`, so the three
can't drift apart.
"""

from werkzeug.security import check_password_hash, generate_password_hash

from avatars import DEFAULT_AVATAR_ID, clamp_stage, is_valid_avatar

# Where every child's adventure starts. Phase 4 introduces the full area
# route; this is the first of them.
HOME_AREA_ID = "home_village"

# A child PIN is optional. When set it is exactly 3 digits — short enough for
# a young child to remember, and it gates nothing sensitive (it only picks a
# profile inside an already-unlocked family session).
CHILD_PIN_LENGTH = 3

# Never sent to a client, under any route.
_PRIVATE_FIELDS = ("child_pin_hash", "_id")


def _streak_default():
    # Fresh dict per call — a shared mutable default would be handed out to
    # every caller and could be mutated by one of them.
    return {"current_days": 0, "last_active_date": None}


def _defaults():
    """The Home Adventure fields every child profile is expected to have."""
    return {
        "avatar_id": DEFAULT_AVATAR_ID,
        "avatar_stage": 1,
        "total_xp": 0,
        "current_area_id": HOME_AREA_ID,
        "streak": _streak_default(),
        "is_active": True,
        "first_login_completed": False,
    }


def migration_defaults():
    """Values `migrate_children.py` back-fills onto existing profiles."""
    return _defaults()


def new_child_fields(avatar_id=None):
    """The Home Adventure fields for a brand-new profile.

    An unknown or missing avatar_id falls back to the default rather than
    raising — callers that want to *reject* a bad id validate it first
    (`validate_avatar_id`), which is what POST /children does.
    """
    fields = _defaults()
    if avatar_id and is_valid_avatar(avatar_id):
        fields["avatar_id"] = avatar_id
    return fields


def validate_avatar_id(avatar_id):
    """(resolved_id, error). A blank id is fine and means "use the default"."""
    if avatar_id is None or avatar_id == "":
        return DEFAULT_AVATAR_ID, None
    if not is_valid_avatar(avatar_id):
        return None, "That avatar is not available"
    return avatar_id, None


def validate_child_pin(raw_pin):
    """(pin_hash, error) for an optional child PIN.

    None/blank means the child has no PIN and can be picked by tapping their
    face. Anything else must be exactly 3 digits; only a valid, non-empty PIN
    is hashed.
    """
    if raw_pin is None:
        return None, None
    pin = str(raw_pin).strip()
    if not pin:
        return None, None
    if not pin.isdigit() or len(pin) != CHILD_PIN_LENGTH:
        return None, f"Child PIN must be {CHILD_PIN_LENGTH} digits"
    return generate_password_hash(pin), None


def check_child_pin(child_doc, raw_pin):
    """True when [raw_pin] matches the child's PIN, or the child has none."""
    stored = (child_doc or {}).get("child_pin_hash")
    if not stored:
        return True
    return check_password_hash(stored, str(raw_pin or ""))


def apply_child_defaults(doc):
    """A child document ready to serialise: defaults filled in, secrets removed.

    Read-only — the caller's document is not modified and nothing is written
    back to MongoDB. `has_pin` is exposed (a boolean) so the profile picker
    knows whether to prompt, while `child_pin_hash` itself never leaves the
    server.
    """
    if doc is None:
        return None

    result = {k: v for k, v in doc.items() if k not in _PRIVATE_FIELDS}

    for key, value in _defaults().items():
        if result.get(key) is None:
            result[key] = value

    # Stored values can still be the wrong shape — an old partial migration, a
    # hand-edited document — so normalise rather than trusting them.
    if not is_valid_avatar(result.get("avatar_id")):
        result["avatar_id"] = DEFAULT_AVATAR_ID
    result["avatar_stage"] = clamp_stage(result.get("avatar_stage"))

    streak = result.get("streak")
    if not isinstance(streak, dict):
        streak = _streak_default()
    result["streak"] = {
        "current_days": int(streak.get("current_days") or 0),
        "last_active_date": streak.get("last_active_date"),
    }

    result["is_active"] = bool(result.get("is_active", True))
    result["first_login_completed"] = bool(result.get("first_login_completed"))
    try:
        result["total_xp"] = int(result.get("total_xp") or 0)
    except (TypeError, ValueError):
        result["total_xp"] = 0

    result["has_pin"] = bool((doc or {}).get("child_pin_hash"))
    return result
