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
