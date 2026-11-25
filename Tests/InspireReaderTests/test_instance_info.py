import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "Sources/CodexBar/Resources/InspireReader"))
from instance_info import ActiveTask, notebook_details, submitted_priority, training_details


class InspireInstanceInfoTests(unittest.TestCase):
    def test_job_includes_hardware_even_when_one_role_has_no_price(self):
        first = {"instance_count": 2, "instance_spec_price_info": {
            "total_price_per_hour": "0.33",
            "gpu_info": {"gpu_type_display": "NVIDIA L40S (45GB)"},
        }}
        second = {"instance_count": 1, "instance_spec": {"gpu_type": "NVIDIA A100"}}
        detail = {"priority": 11, "priority_level": "LOW", "framework_config": [first, second]}

        def sdk_view(record):
            if record is detail:
                return {"priority": record["priority"], "priority_level": record["priority_level"]}
            price = record["framework_config"][0].get("instance_spec_price_info", {})
            return {"resource": {"gpu_type": price.get("gpu_info", {}).get("gpu_type_display")}}

        result = training_details(detail, sdk_view)
        self.assertEqual(result.gpu_type, "NVIDIA L40S (45GB) / NVIDIA A100")
        self.assertEqual(result.priority_level, "LOW")
        self.assertIsNone(result.rate)

    def test_training_price_counts_instances_and_deduplicates_models(self):
        block = {"instance_count": 2, "instance_spec_price_info": {"total_price_per_hour": "0.33"}}
        result = training_details(
            {"framework_config": [block, block]},
            lambda _record: {"resource": {"gpu_type": "NVIDIA L40S (45GB)"}},
        )
        self.assertEqual(result.rate, 1.32)
        self.assertEqual(result.gpu_type, "NVIDIA L40S (45GB)")

    def test_notebook_keeps_the_projected_model_and_priority_tier(self):
        result = notebook_details(
            {"resource_spec_price": {"total_price_per_hour": "0.50"}},
            lambda _record: {"resource": {"gpu_type": "NVIDIA H100"}, "priority_level": "HIGH"},
        )
        self.assertEqual(result.gpu_type, "NVIDIA H100")
        self.assertEqual(result.rate, 0.5)
        self.assertEqual(result.priority_level, "HIGH")

    def test_submitted_priority_ignores_missing_values_and_internal_scores(self):
        self.assertEqual(submitted_priority(1), 1)
        self.assertEqual(submitted_priority(10), 10)
        self.assertIsNone(submitted_priority(0))
        self.assertIsNone(submitted_priority(11))
        self.assertIsNone(submitted_priority(None))

    def test_scoped_task_preserves_idle_values_and_absent_samples(self):
        row = {"id": "test-id", "name": "demo", "type": "distributed_training", "status": "RUNNING",
               "user": {"id": "mine"}, "project": {"name": "Public demo"}, "priority": 4,
               "cpu": {"total": 8, "usage_rate": 0},
               "gpu": {"total": 2}}
        task = ActiveTask.from_dimension(row, "mine", {"Public demo"})
        self.assertEqual(task.priority, 4)
        self.assertEqual(task.cards, 2)
        self.assertEqual(task.cpu_utilization, 0.0)
        self.assertIsNone(task.gpu_utilization)
        row["gpu"]["usage_rate"] = "0.375"
        self.assertEqual(ActiveTask.from_dimension(row, "mine", {"Public demo"}).gpu_utilization, 0.375)
        row["gpu"]["total"] = 0
        self.assertIsNone(ActiveTask.from_dimension(row, "mine", {"Public demo"}).gpu_utilization)
        self.assertIsNone(ActiveTask.from_dimension(row, "other", {"Public demo"}))
        self.assertIsNone(ActiveTask.from_dimension(row, "mine", {"Other project"}))
        row["status"] = "STOPPED"
        self.assertIsNone(ActiveTask.from_dimension(row, "mine", {"Public demo"}))
