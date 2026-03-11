#!/usr/bin/env python3
"""
Tests for nvidia-tuning-gke prepare_nvidia_configs.sh script.

Verifies that the prepare step:
- Discovers profiles from profiles/{accelerator}/{intent}/
- Copies sysctl.conf (and for GB200 service_containerd.conf) into configmaps/
- Does not leave grub.conf in configmaps (GKE does not use grub)
- Fails with clear errors for missing/invalid accelerator or intent
"""

import pytest

from tests.helpers.assertions import (
    assert_exit_code,
    assert_output_contains,
    assert_file_contains,
)
from tests.helpers.docker_test import DockerTestRunner

CONFIGMAPS_DIR = "/skyhook-package/configmaps"


@pytest.mark.parametrize(
    "accelerator,intent,expected_sysctl_line,expect_containerd",
    [
        ("h100", "inference", "kernel.sched_latency_ns=1000000", False),
        ("h100", "multiNodeTraining", "net.ipv4.tcp_congestion_control=bbr", False),
        ("gb200", "inference", "vm.swappiness=1", True),
        ("gb200", "multiNodeTraining", "net.core.default_qdisc=fq", True),
    ],
)
def test_prepare_nvidia_configs_all_profiles(
    base_image, accelerator, intent, expected_sysctl_line, expect_containerd
):
    """Prepare copies correct sysctl.conf and optional service_containerd.conf for each profile."""
    runner = DockerTestRunner(package="nvidia-tuning-gke", base_image=base_image)
    try:
        configmaps = {"accelerator": accelerator, "intent": intent}
        result = runner.run_script(
            script="prepare_nvidia_configs.sh",
            configmaps=configmaps,
        )
        assert_exit_code(result, 0)
        assert_output_contains(result.stdout, f"Preparing tuning configmaps for profile: {accelerator}/{intent}")
        assert_output_contains(result.stdout, "Copied sysctl.conf")

        assert_file_contains(runner, f"{CONFIGMAPS_DIR}/sysctl.conf", expected_sysctl_line)
        assert not runner.file_exists(f"{CONFIGMAPS_DIR}/grub.conf"), "grub.conf must not be in configmaps (GKE)"

        if expect_containerd:
            assert_output_contains(result.stdout, "Copied service_containerd.conf")
            assert_file_contains(runner, f"{CONFIGMAPS_DIR}/service_containerd.conf", "LimitSTACK=67108864")
        else:
            assert not runner.file_exists(f"{CONFIGMAPS_DIR}/service_containerd.conf")
    finally:
        runner.cleanup()


def test_prepare_nvidia_configs_no_grub_in_configmaps(base_image):
    """Ensure grub.conf is never present in configmaps after prepare."""
    runner = DockerTestRunner(package="nvidia-tuning-gke", base_image=base_image)
    try:
        result = runner.run_script(
            script="prepare_nvidia_configs.sh",
            configmaps={"accelerator": "h100", "intent": "inference"},
        )
        assert_exit_code(result, 0)
        assert not runner.file_exists(f"{CONFIGMAPS_DIR}/grub.conf"), "grub.conf must not exist (GKE has no grub)"
    finally:
        runner.cleanup()


def test_prepare_nvidia_configs_invalid_accelerator(base_image):
    """Unknown accelerator fails with available list."""
    runner = DockerTestRunner(package="nvidia-tuning-gke", base_image=base_image)
    try:
        result = runner.run_script(
            script="prepare_nvidia_configs.sh",
            configmaps={"accelerator": "x99", "intent": "inference"},
        )
        assert_exit_code(result, 1)
        assert_output_contains(result.stdout, "unknown accelerator")
        assert_output_contains(result.stdout, "x99")
    finally:
        runner.cleanup()


def test_prepare_nvidia_configs_invalid_intent(base_image):
    """Unknown intent for valid accelerator fails with available list."""
    runner = DockerTestRunner(package="nvidia-tuning-gke", base_image=base_image)
    try:
        result = runner.run_script(
            script="prepare_nvidia_configs.sh",
            configmaps={"accelerator": "h100", "intent": "training"},
        )
        assert_exit_code(result, 1)
        assert_output_contains(result.stdout, "unknown intent")
        assert_output_contains(result.stdout, "training")
    finally:
        runner.cleanup()


def test_prepare_nvidia_configs_missing_accelerator(base_image):
    """Missing accelerator configmap fails."""
    runner = DockerTestRunner(package="nvidia-tuning-gke", base_image=base_image)
    try:
        result = runner.run_script(
            script="prepare_nvidia_configs.sh",
            configmaps={"intent": "inference"},
        )
        assert_exit_code(result, 1)
        assert_output_contains(result.stdout, "accelerator")
    finally:
        runner.cleanup()


def test_prepare_nvidia_configs_missing_intent(base_image):
    """Missing intent configmap fails."""
    runner = DockerTestRunner(package="nvidia-tuning-gke", base_image=base_image)
    try:
        result = runner.run_script(
            script="prepare_nvidia_configs.sh",
            configmaps={"accelerator": "h100"},
        )
        assert_exit_code(result, 1)
        assert_output_contains(result.stdout, "intent")
    finally:
        runner.cleanup()


def test_prepare_nvidia_configs_check_pass(base_image):
    """After prepare, prepare_nvidia_configs_check.sh passes (run check in same container)."""
    runner = DockerTestRunner(package="nvidia-tuning-gke", base_image=base_image)
    try:
        prepare_result = runner.run_script(
            script="prepare_nvidia_configs.sh",
            configmaps={"accelerator": "gb200", "intent": "inference"},
        )
        assert_exit_code(prepare_result, 0)

        # Run check script in the same container (configmaps already populated by prepare)
        env = {
            "SKYHOOK_DIR": "/skyhook-package",
            "STEP_ROOT": "/skyhook-package/skyhook_dir",
        }
        exec_result = runner.container.exec_run(
            ["/bin/bash", "-c", "/skyhook-package/skyhook_dir/prepare_nvidia_configs_check.sh 2>&1"],
            workdir="/skyhook-package",
            environment=env,
        )
        assert exec_result.exit_code == 0, exec_result.output.decode("utf-8", errors="replace")
        out = exec_result.output.decode("utf-8", errors="replace")
        assert "Prepare check passed for profile: gb200/inference" in out
    finally:
        runner.cleanup()


def test_prepare_nvidia_configs_check_fails_without_prepare(base_image):
    """prepare_nvidia_configs_check.sh fails if sysctl.conf is missing (prepare not run)."""
    runner = DockerTestRunner(package="nvidia-tuning-gke", base_image=base_image)
    try:
        # Only write accelerator and intent; do not run prepare (so no sysctl.conf)
        result = runner.run_script(
            script="prepare_nvidia_configs_check.sh",
            configmaps={"accelerator": "h100", "intent": "inference"},
        )
        assert_exit_code(result, 1)
        assert_output_contains(result.stdout, "sysctl.conf")
    finally:
        runner.cleanup()
