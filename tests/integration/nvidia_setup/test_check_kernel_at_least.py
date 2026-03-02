#!/usr/bin/env python3
"""
Tests for check_kernel_at_least in ensure_kernel.sh.

The check compares upstream kernel versions (before first '-') so that
e.g. 6.17.0-1007-aws is correctly considered >= 6.14.0-1018-aws (6.17 >= 6.14).
"""

from tests.helpers.docker_test import DockerTestRunner


def _run_check(runner: DockerTestRunner, current_kernel: str, required_kernel: str) -> int:
    """Run the check script; return exit code."""
    result = runner.run_script(
        script="steps/run_check_kernel_at_least_test.sh",
        configmaps={},
        env_vars={
            "CURRENT_KERNEL": current_kernel,
            "REQUIRED_KERNEL": required_kernel,
        },
    )
    return result.exit_code


def test_current_newer_upstream_passes():
    """6.17.0-1007-aws >= 6.14.0-1018-aws (upstream 6.17 >= 6.14); was previously failing with sort -V on full string."""
    runner = DockerTestRunner(package="nvidia-setup")
    try:
        exit_code = _run_check(runner, "6.17.0-1007-aws", "6.14.0-1018-aws")
        assert exit_code == 0
    finally:
        runner.cleanup()


def test_current_same_upstream_passes():
    """6.14.0-1000-aws >= 6.14.0-1018-aws (same upstream)."""
    runner = DockerTestRunner(package="nvidia-setup")
    try:
        exit_code = _run_check(runner, "6.14.0-1000-aws", "6.14.0-1018-aws")
        assert exit_code == 0
    finally:
        runner.cleanup()


def test_current_older_upstream_fails():
    """6.13.0-1000-aws < 6.14.0-1018-aws (upstream 6.13 < 6.14)."""
    runner = DockerTestRunner(package="nvidia-setup")
    try:
        exit_code = _run_check(runner, "6.13.0-1000-aws", "6.14.0-1018-aws")
        assert exit_code == 1
    finally:
        runner.cleanup()


def test_current_exact_required_passes():
    """6.14.0-1018-aws >= 6.14.0-1018-aws (equal)."""
    runner = DockerTestRunner(package="nvidia-setup")
    try:
        exit_code = _run_check(runner, "6.14.0-1018-aws", "6.14.0-1018-aws")
        assert exit_code == 0
    finally:
        runner.cleanup()
