"""Persistence and UTC+8 billing windows shared with the local Inspire collector."""

import json
import os
import tempfile
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path

PUBLIC = "公共科研项目"
DAY = 86400
TZ = timezone(timedelta(hours=8))


def number(value):
    try:
        result = Decimal(str(value).replace(",", "").strip())
        return result if result.is_finite() else None
    except (InvalidOperation, ValueError):
        return None


def cents(value):
    result = number(value)
    return round(result * 100) if result is not None else None


def weekly(ts):
    now = datetime.fromtimestamp(ts, TZ)
    monday = (now - timedelta(days=now.weekday())).replace(hour=10, minute=0, second=0, microsecond=0)
    if monday > now:
        monday -= timedelta(days=7)
    return int(monday.timestamp()), int((monday + timedelta(days=7)).timestamp())


def day_windows(ts, count=30):
    midnight = datetime.fromtimestamp(ts, TZ).replace(hour=0, minute=0, second=0, microsecond=0)
    for ago in range(count - 1, -1, -1):
        day = midnight - timedelta(days=ago)
        start = int(day.timestamp())
        yield day.date().isoformat(), start, min(ts, start + DAY - 1)


def read_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {}


def write_json(path, value):
    path = Path(path)
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".pending-", delete=False) as stream:
        pending = Path(stream.name)
        try:
            stream.write(json.dumps(value, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode())
            stream.close()
            os.replace(pending, path)
        finally:
            pending.unlink(missing_ok=True)
