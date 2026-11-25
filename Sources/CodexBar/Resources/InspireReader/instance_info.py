"""Present the same hardware and priority labels as the Inspire CLI."""

from dataclasses import dataclass

from storage import number


@dataclass(frozen=True)
class InstanceDetails:
    rate: float | None = None
    gpu_type: str | None = None
    priority_level: str | None = None


@dataclass(frozen=True)
class ActiveTask:
    task_id: str
    name: str
    task_type: str
    project: str
    cards: int
    priority: int | None
    cpu_utilization: float | None
    gpu_utilization: float | None

    @classmethod
    def from_dimension(cls, row, user_id, projects):
        if not isinstance(row, dict):
            return None
        user, project = row.get("user") or {}, row.get("project") or {}
        if not isinstance(user, dict) or not isinstance(project, dict):
            return None
        owner = str(user.get("id") or user.get("user_id") or "")
        project_name = project.get("name") or project.get("project_name")
        task_id = str(row.get("id") or "")
        if (owner != user_id or project_name not in projects or not task_id
                or str(row.get("status") or "").upper() not in {"RUNNING", "JOB_RUNNING"}):
            return None
        return cls(
            task_id=task_id, name=str(row.get("name") or "未命名实例"), task_type=str(row.get("type") or ""),
            project=project_name, cards=int(allocation(row, "gpu") or 0),
            priority=submitted_priority(row.get("priority")),
            cpu_utilization=utilization(row, "cpu"), gpu_utilization=utilization(row, "gpu"),
        )


def allocation(row, resource):
    block = row.get(resource)
    total = number(block.get("total")) if isinstance(block, dict) else None
    return total if total is not None and total > 0 else None


def utilization(row, resource):
    if allocation(row, resource) is None:
        return None
    value = number(row[resource].get("usage_rate"))
    return float(value) if value is not None and 0 <= value <= 1 else None


def gpu_type(view):
    resource = view.get("resource")
    if isinstance(resource, dict):
        return resource.get("gpu_type") or None
    return None


def priority_level(view):
    value = view.get("priority_level")
    return value if value in ("LOW", "HIGH") else None


def submitted_priority(value):
    # TaskUsage.priority uses 0 for a missing result. GetJob.priority is a
    # different field: on some tasks it reports an internal score such as 11.
    return value if isinstance(value, int) and not isinstance(value, bool) and 1 <= value <= 10 else None


def notebook_details(detail, status_view):
    view = status_view(detail)
    price = number((detail.get("resource_spec_price") or {}).get("total_price_per_hour"))
    rate = float(price) if price is not None and price >= 0 else None
    return InstanceDetails(rate, gpu_type(view), priority_level(view))


def training_details(detail, status_view):
    view = status_view(detail)
    blocks = detail.get("framework_config") or []
    if isinstance(blocks, dict):
        blocks = [blocks]
    prices, models = [], []
    for block in blocks:
        model = gpu_type(status_view({"framework_config": [block]}))
        instance_spec = block.get("instance_spec") or {}
        model = model or instance_spec.get("gpu_type")
        if model:
            models.append(model)
        unit = number((block.get("instance_spec_price_info") or {}).get("total_price_per_hour"))
        count = number(block.get("instance_count"))
        if unit is not None and unit >= 0 and count is not None and count > 0:
            prices.append(unit * count)
    rate = float(sum(prices)) if prices and len(prices) == len(blocks) else None
    return InstanceDetails(rate, " / ".join(dict.fromkeys(models)) or gpu_type(view), priority_level(view))
