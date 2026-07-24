"""The animal buddies a child can be assigned.

Only the ids live here. The artwork paths are held by the Flutter side
(frontend/lib/avatar_config.dart) because assets are bundled at build time —
a path invented by the server at runtime could not be loaded by the client
anyway. This module's job is narrower: reject an avatar_id the app doesn't
have art for, so a typo or a stale client can't write an unrenderable child
document.

Keep AVATAR_IDS in step with kAvatars in avatar_config.dart. Retire an avatar
by removing it from the picker on the Dart side, NOT by deleting it here —
children who already chose it still need their id to validate.
"""

# Order matches kAvatars' sortOrder, though nothing depends on it server-side.
AVATAR_IDS = (
    "kitten",
    "panda",
    "elephant",
    "penguin",
    "unicorn",
)

VALID_AVATAR_IDS = frozenset(AVATAR_IDS)

# Assigned to a child with no avatar, including every profile created before
# avatars existed. Must match kDefaultAvatarId in avatar_config.dart.
DEFAULT_AVATAR_ID = "kitten"

# The artwork covers three growth stages; a stored stage is clamped to it.
MIN_AVATAR_STAGE = 1
MAX_AVATAR_STAGE = 3


def is_valid_avatar(avatar_id):
    """True when there is artwork for this id."""
    return avatar_id in VALID_AVATAR_IDS


def clamp_stage(stage):
    """Coerce any stored stage into the range the artwork covers.

    Legacy documents have no stage at all, and a future reward rule could
    overshoot the final stage; neither should ever reach the client as a
    number it can't render.
    """
    try:
        value = int(stage)
    except (TypeError, ValueError):
        return MIN_AVATAR_STAGE
    return max(MIN_AVATAR_STAGE, min(MAX_AVATAR_STAGE, value))
