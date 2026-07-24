from datetime import datetime, timedelta

# All logs are written with datetime.utcnow(), but parents and teachers read
# their reports in Kuala Lumpur time (GMT+8). Without this shift a 7am local
# scan (stored as 11pm UTC the day before) would be filed under the previous
# calendar day, so "progress by day" would look wrong to the user.
LOCAL_UTC_OFFSET = timedelta(hours=8)  # Asia/Kuala_Lumpur, GMT+8
_WEEKDAYS = ("Monday", "Tuesday", "Wednesday", "Thursday",
             "Friday", "Saturday", "Sunday")


def _to_local(dt):
    """Shift a stored UTC datetime into local (GMT+8) time, or None."""
    if not isinstance(dt, datetime):
        return None
    return dt + LOCAL_UTC_OFFSET


def _local_day(dt):
    """Return (YYYY-MM-DD, weekday name) for the LOCAL day a UTC log falls on."""
    local = _to_local(dt)
    if local is None:
        return None, None
    return local.strftime("%Y-%m-%d"), _WEEKDAYS[local.weekday()]


def _local_time(dt):
    """Return 'HH:MM' in local time, or '' when the value isn't a datetime."""
    local = _to_local(dt)
    return local.strftime("%H:%M") if local else ""


def local_today():
    """Today's local (GMT+8) calendar date as 'YYYY-MM-DD'."""
    return (datetime.utcnow() + LOCAL_UTC_OFFSET).strftime("%Y-%m-%d")


def local_day_start_utc(days_ago=0):
    """The UTC instant local midnight fell on, [days_ago] days back.

    Lets "what happened today" be a plain indexed range query on created_at
    instead of pulling every log and bucketing it in Python — logs are stored
    in UTC but a child's day starts at local midnight.
    """
    local_now = datetime.utcnow() + LOCAL_UTC_OFFSET
    local_midnight = (local_now - timedelta(days=days_ago)).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    return local_midnight - LOCAL_UTC_OFFSET


def _clean(doc):
    """Strip _id and convert datetime values to ISO strings."""
    if doc is None:
        return None
    result = {}
    for k, v in doc.items():
        if k == "_id":
            continue
        result[k] = v.isoformat() if isinstance(v, datetime) else v
    return result
