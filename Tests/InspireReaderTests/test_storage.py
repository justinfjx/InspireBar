import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "Sources/CodexBar/Resources/InspireReader"))
from storage import cents, day_windows, read_json, weekly, write_json


class InspireStorageTests(unittest.TestCase):
    def test_monday_reset_and_local_dates(self):
        at = int(datetime.fromisoformat("2025-06-02T10:00:00+08:00").timestamp())
        self.assertEqual(weekly(at - 1)[1], at)
        self.assertEqual(weekly(at), (at, at + 7 * 86400))
        yesterday, today = day_windows(at, 2)
        self.assertEqual(yesterday[0], "2025-06-01")
        self.assertEqual(yesterday[2], today[1] - 1)
        self.assertEqual(today, ("2025-06-02", at - 10 * 3600, at))

    def test_money_stays_in_hundredths(self):
        self.assertEqual(cents("123.4500000000001"), 12345)
        self.assertEqual(cents("1,672.10"), 167210)
        self.assertEqual(cents(0), 0)
        self.assertIsNone(cents("NaN"))
        self.assertIsNone(cents(None))

    def test_archive_replace_keeps_money_and_private_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "archive.json"
            self.assertEqual(read_json(path), {})
            write_json(path, {"samples": [[1749002400, 52000]]})
            charge = {"days": {"2025-06-04": {"spend": {"公共科研项目": 5400}}}}
            write_json(path, charge)
            self.assertEqual(read_json(path), charge)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(list(Path(directory).iterdir()), [path])
