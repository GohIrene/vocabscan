"""The adventure route: six themed areas a child grows one at a time.

Areas are a *visual* theme and nothing more. They never restrict what can be
scanned — a child growing Fruit Garden may scan a chair, a car or a cat, and
every one of them counts. Nothing in this module filters recognition, and
nothing downstream should either.

Progress is stored per area as a plain 0-100 integer, which doubles as the
percentage. Both the decoration stage and the key count are *derived* from
that one number rather than tracked separately, so they can never disagree
with it.

Phase 3 reads this for the home summary; Phase 4 builds the map and area
screens on the same definitions.
"""

# Order is the unlock route: finish one area and the next opens.
AREAS = (
    {"area_id": "home_village", "name": "Home Village", "emoji": "🏡"},
    {"area_id": "fruit_garden", "name": "Fruit Garden", "emoji": "🍎"},
    {"area_id": "animal_forest", "name": "Animal Forest", "emoji": "🦊"},
    {"area_id": "home_corner", "name": "Cozy Home Corner", "emoji": "🛋️"},
    {"area_id": "vehicle_valley", "name": "Vehicle Valley", "emoji": "🚗"},
    {"area_id": "treasure_castle", "name": "Treasure Castle", "emoji": "🏰"},
)

AREA_IDS = tuple(a["area_id"] for a in AREAS)
FIRST_AREA_ID = AREA_IDS[0]

MAX_PROGRESS = 100
# One decoration stage (and one key) per 20 points: 0/20/40/60/80/100.
PROGRESS_PER_STAGE = 20
MAX_STAGE = MAX_PROGRESS // PROGRESS_PER_STAGE  # 5

# Where per-area points live on the child document.
PROGRESS_FIELD = "area_progress"


def area_by_id(area_id):
    for area in AREAS:
        if area["area_id"] == area_id:
            return area
    return None


def is_valid_area(area_id):
    return area_id in AREA_IDS


def area_index(area_id):
    """Position on the route, or -1 for an unknown area."""
    try:
        return AREA_IDS.index(area_id)
    except ValueError:
        return -1


def next_area_id(area_id):
    """The area unlocked when [area_id] completes, or None at the end."""
    i = area_index(area_id)
    if i < 0 or i + 1 >= len(AREA_IDS):
        return None
    return AREA_IDS[i + 1]


def clamp_progress(value):
    try:
        points = int(value)
    except (TypeError, ValueError):
        return 0
    return max(0, min(MAX_PROGRESS, points))


def visual_stage(progress):
    """Decoration stage 0-5 for a 0-100 progress value.

    Fixed bands rather than a simulation: 0-19% is stage 0, 20-39% stage 1,
    and so on, with 100% the only way to reach stage 5.
    """
    return min(clamp_progress(progress) // PROGRESS_PER_STAGE, MAX_STAGE)


def keys_for_progress(progress):
    """Keys earned in an area, derived from its progress — never stored.

    0-19% = 0 keys, 20-39% = 1, 40-59% = 2, 60-79% = 3, 80-99% = 4, 100% = 5.
    Deriving means a key count can't drift out of step with the progress bar.
    """
    return visual_stage(progress)


def get_area_progress(child, area_id):
    """A child's 0-100 progress in one area (0 when they've never been)."""
    stored = (child or {}).get(PROGRESS_FIELD) or {}
    if not isinstance(stored, dict):
        return 0
    return clamp_progress(stored.get(area_id, 0))


def all_area_progress(child):
    """Progress for every area on the route, absent ones reading as 0."""
    return {area_id: get_area_progress(child, area_id) for area_id in AREA_IDS}


def current_area_id(child):
    """The area a child is growing now: the first one not yet finished.

    Derived from progress rather than read from the stored `current_area_id`,
    which makes "finish an area and the next unlocks" fall out automatically
    and leaves no way for the stored pointer to disagree with the numbers.
    Phase 5 keeps the stored field in step for cheap reads elsewhere, but this
    is the authority.

    Once every area is complete there is nothing left to grow, so the last
    area stays current and simply reads as finished.
    """
    progress = all_area_progress(child)
    for area_id in AREA_IDS:
        if progress.get(area_id, 0) < MAX_PROGRESS:
            return area_id
    return AREA_IDS[-1]


def stored_current_area_id(child):
    """The `current_area_id` written on the document, healed if it's junk.

    Kept for the write side (Phase 5) to compare against; readers should use
    [current_area_id].
    """
    stored = (child or {}).get("current_area_id")
    return stored if is_valid_area(stored) else FIRST_AREA_ID


def area_status(child, area_id):
    """'completed', 'current' or 'locked'.

    An area is unlocked once every earlier area on the route is finished, so
    status is recomputed from progress rather than stored as its own flag —
    one less thing that can disagree with the numbers.
    """
    progress = all_area_progress(child)
    if progress.get(area_id, 0) >= MAX_PROGRESS:
        return "completed"
    index = area_index(area_id)
    if index < 0:
        return "locked"
    for earlier in AREA_IDS[:index]:
        if progress.get(earlier, 0) < MAX_PROGRESS:
            return "locked"
    return "current"


def area_summary(child, area_id):
    """One area as the client draws it."""
    area = area_by_id(area_id) or {}
    points = get_area_progress(child, area_id)
    return {
        "area_id": area_id,
        "area_name": area.get("name", area_id),
        "emoji": area.get("emoji", ""),
        "progress_percentage": points,
        "visual_stage": visual_stage(points),
        "keys": keys_for_progress(points),
        "max_keys": MAX_STAGE,
        "status": area_status(child, area_id),
        # A locked area can be looked at but not grown — the map lets a child
        # see where they're heading without being able to jump ahead.
        "can_preview": True,
        "can_grow": area_status(child, area_id) == "current",
    }


def adventure_summary(child):
    """The whole route: every area, plus where the child stands on it."""
    areas = [area_summary(child, area_id) for area_id in AREA_IDS]
    current = current_area_id(child)
    completed = [a for a in areas if a["status"] == "completed"]
    return {
        "current_area_id": current,
        "areas": areas,
        "completed_count": len(completed),
        "area_count": len(areas),
        # Keys held across the whole route, so the home screen and the map
        # agree on one number.
        "total_keys": sum(a["keys"] for a in areas),
        "max_total_keys": MAX_STAGE * len(areas),
        "all_completed": len(completed) == len(areas),
    }
