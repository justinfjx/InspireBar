"""Sample Inspire through the Mac's authorized CLI session. No token export."""

import argparse
import fcntl
import logging
import os
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from inspire import InspireClient
from inspire.accounts import current_account, validate_name
from inspire.platform.web.browser_api import (
    get_current_user, get_job_detail_v2, get_notebook_detail,
)
from inspire.platform.web.session import build_requests_session, get_web_session
from inspire.services.job.job_output import public_job_status
from inspire.services.notebook.notebook_output import public_notebook

from instance_info import ActiveTask, InstanceDetails, notebook_details, training_details
from storage import DAY, PUBLIC, cents, day_windows, read_json, weekly, write_json

BASE = "https://qz.sii.edu.cn"
LOG = logging.getLogger("inspire-bar")


class AccountMismatch(ValueError):
    pass


def post(http, route, action, referer, body):
    res = http.post(f"{BASE}/api/v2/{route}?Action={action}", json=body,
                    headers={"Referer": BASE + referer}, timeout=(5, 15), allow_redirects=False)
    if res.status_code in (401, 403):
        raise PermissionError(action)
    if res.status_code != 200:
        raise RuntimeError(f"{action}: HTTP {res.status_code}")
    obj = res.json()
    result = obj.get("Result")
    if obj.get("ResponseMetadata", {}).get("Error") or not isinstance(result, dict):
        raise RuntimeError(f"{action}: unexpected result")
    return result


def paged(http, route, action, referer, request, *, page_key="page", items_key="items", unique_key=None):
    items, seen, page = [], set(), 1
    while True:
        r = post(http, route, action, referer, dict(request, **{page_key: page, "page_size": 100}))
        batch = r.get(items_key)
        if not isinstance(batch, list):
            raise ValueError(f"{action}: missing {items_key}")
        total = int(r.get("total", len(batch)))
        before = len(items)
        for item in batch:
            key = str(item.get(unique_key) or "") if unique_key and isinstance(item, dict) else None
            if key:
                if key in seen:
                    continue
                seen.add(key)
            items.append(item)
        if len(items) >= total:
            return items
        if len(items) == before:
            raise ValueError(f"{action}: incomplete result")
        page += 1


def projects(http):
    rows = paged(http, "project", "ListProjects", "/projects", {"filter": {"check_admin": True}})
    output = []
    for item in rows:
        shared, personal = cents(item.get("remain_budget")), cents(item.get("member_remain_budget"))
        member = personal is not None
        output.append(dict(name=item["name"], balance=personal if member else shared,
                           scope="member" if member else "shared"))
    if not any(p["name"] == PUBLIC and p["scope"] == "member" and p["balance"] is not None for p in output):
        raise ValueError("Public research project did not report a member balance")
    return sorted(output, key=lambda p: (p["name"] != PUBLIC, p["name"]))


def bill(http, start, end):
    rows = paged(http, "billing", "ListUserBillings", "/historyResourceUsage",
                 {"filter": {"start": str(start), "end": str(end)}, "order_by": {}})
    return {r["name"]: cost for r in rows if (cost := cents(r.get("current"))) is not None}


def task_details(task, session):
    kind = task.task_type.lower()
    if kind in {"interactive_modeling", "notebook"} or task.task_id.startswith("notebook-"):
        return notebook_details(get_notebook_detail(task.task_id, session=session), public_notebook)
    if kind in {"distributed_training", "train", "job"} or task.task_id.startswith("job-"):
        return training_details(get_job_detail_v2(task.task_id, session=session), public_job_status)
    return InstanceDetails()


def activity(account, session, uid, project_names):
    with InspireClient(account=account, timeout=18) as c:
        first = c.workspaces.list(limit=100)
        workspaces = list(first.items)
        page = first
        while page.next_cursor:
            page = c.workspaces.list(limit=100, cursor=page.next_cursor)
            workspaces.extend(page.items)
    if not workspaces:
        raise ValueError("No visible Inspire workspaces")

    def scan(ws):
        try:
            # The SDK's TaskUsage makes a missing usage_rate indistinguishable from idle (0%).
            # Read the same scoped dimension rows so the dashboard can keep those states distinct.
            with build_requests_session(session, BASE) as http:
                rows = paged(http, "workspace", "ListTaskDimension", "/jobs/distributedTraining",
                             {"filter": {"workspace_id": ws.ref.key, "user_id": uid}},
                             page_key="PageNumber", items_key="task_dimensions", unique_key="id")
        except Exception as err:
            LOG.warning("%s activity: %s", ws.name, type(err).__name__)
            return ws.name, None
        items = []
        for row in rows:
            task = ActiveTask.from_dimension(row, uid, project_names)
            if task is None:
                continue
            if task.cards == 0 and ws.name != "昇腾卡公共空间":
                details = InstanceDetails(rate=0)
            else:
                try:
                    details = task_details(task, session)
                except Exception as err:
                    LOG.warning("Workload details: %s", type(err).__name__)
                    details = InstanceDetails()
            items.append(dict(identifier=task.task_id, name=task.name, project=task.project,
                              workspace=ws.name, cards=task.cards, gpu_type=details.gpu_type,
                              rate=details.rate, priority=task.priority, priority_level=details.priority_level,
                              cpu_utilization=task.cpu_utilization, gpu_utilization=task.gpu_utilization))
        return ws.name, items

    tasks, missing = [], []
    with ThreadPoolExecutor(max_workers=4) as pool:
        for workspace, items in pool.map(scan, workspaces):
            if items is None:
                missing.append(workspace)
            else:
                tasks.extend(items)
    return sorted(tasks, key=lambda x: (x["project"] != PUBLIC, x["project"], x["name"])), missing


def sync(state, account, save):
    session = get_web_session(account=account)
    user = get_current_user(session)
    uid = str(user.get("id") or user.get("user_id") or "")
    if not uid or state.get("_subject", uid) != uid:
        raise AccountMismatch("Inspire account does not match this archive")
    state["_subject"] = uid

    with build_requests_session(session, BASE) as http:
        at = int(time.time())
        pr = projects(http)
        known = {row["name"] for row in pr}
        public = next(x["balance"] for x in pr if x["name"] == PUBLIC)
        try:
            tasks, missing = activity(account, session, uid, known)
        except Exception as err:
            LOG.warning("Workspaces: %s", type(err).__name__)
            tasks, missing = [], ["工作空间列表"]
        state["latest"] = dict(at=at, projects=pr, active=tasks, missing_workspaces=missing)
        state.pop("collection_error", None)
        state["samples"] = [r for r in state.get("samples", []) if at - 8 * 7 * DAY <= r[0] < at] + [[at, public]]
        save()

        now = int(time.time())
        windows = list(day_windows(now))
        daily = state.setdefault("days", {})
        try:
            overview = dict(at=now, ranges={str(n): bill(http, windows[-n][1], now) for n in (7, 15, 30)})
            start, _ = weekly(now)
            overview["cycle"] = dict(start=start, spend=bill(http, start, now))
            state["billing"] = overview
            for i, (date, lo, hi) in enumerate(reversed(windows)):
                cached = daily.get(date, {})
                if not cached or cached["end"] < hi or (i <= 2 and now - cached["updated"] >= 6 * 3600):
                    daily[date] = dict(end=hi, updated=now, spend=bill(http, lo, hi))
            state["days"] = {date: daily[date] for date, _, _ in windows if date in daily}
        except Exception as err:
            LOG.warning("Billing: %s", type(err).__name__)
            state["billing_error"] = "账单更新中断"
        else:
            state.pop("billing_error", None)
        save()
    LOG.info("Sample collected: %d projects, %d active allocations, %d billed days", len(pr), len(tasks), len(state["days"]))


def run(runtime, import_archive):
    os.umask(0o077)
    runtime.mkdir(mode=0o700, parents=True, exist_ok=True)
    out = runtime / "snapshot.json"
    with (runtime / "collector.lock").open("w") as lock:
        # A collector can finish after its menu-bar process exits during an update.
        # Wait for it to publish before opening the archive for the next sample.
        fcntl.flock(lock, fcntl.LOCK_EX)
        account = current_account()
        if not account:
            write_json(out, {"collection_error": "请先在终端运行 inspire login。"})
            return 1
        account_dir = runtime / "accounts" / validate_name(account)
        account_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
        archive = account_dir / "archive.json"
        state = read_json(archive)
        candidate = state
        if not state and import_archive is not None:
            candidate = read_json(import_archive)
            if not candidate.get("_subject"):
                raise ValueError("The import must contain an Inspire account identifier")

        def publish(value):
            write_json(out, dict({k: v for k, v in value.items() if k != "_subject"}, account=account))

        def save():
            write_json(archive, candidate)
            publish(candidate)

        try:
            sync(candidate, account, save)
        except AccountMismatch:
            publish({"collection_error": "当前 Inspire 账号与历史记录不一致。请使用不同的 CLI 账号别名。"})
            return 1
        except Exception as err:
            kind = type(err).__name__
            LOG.warning("Inspire collection: %s", kind)
            message = ("Inspire 登录已失效，请在终端运行 inspire login。"
                       if "Auth" in kind or isinstance(err, PermissionError) else "Inspire 暂时未返回数据。")
            publish(dict(state, collection_error=message))
            return 1
        return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime", required=True, type=Path)
    parser.add_argument("--import-archive", type=Path)
    options = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
    raise SystemExit(run(options.runtime, options.import_archive))
