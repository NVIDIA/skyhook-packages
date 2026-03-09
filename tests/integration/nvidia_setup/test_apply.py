#!/usr/bin/env python3
"""
Tests for nvidia-setup apply.sh script.
"""

import pytest

from tests.helpers.assertions import (
    assert_exit_code,
    assert_output_contains,
    assert_output_not_contains,
)
from tests.helpers.docker_test import DockerTestRunner


def test_unsupported_combination():
    """Test that unsupported service/accelerator combinations fail with proper error."""
    runner = DockerTestRunner(package="nvidia-setup")
    try:
        result = runner.run_script(
            script="apply.sh",
            configmaps={"service": "invalid", "accelerator": "invalid"}
        )
        
        assert_exit_code(result, 1)
        assert_output_contains(result.stdout, "Unsupported combination")
        assert_output_contains(result.stdout, "Supported:")
    finally:
        runner.cleanup()

@pytest.mark.skip(reason="Skipping test_apply_aws_h100. Kernel is flaky based on where it is run.")
def test_apply_aws_h100(base_image):
    """Test apply.sh with aws-h100 combination."""
    runner = DockerTestRunner(package="nvidia-setup", base_image=base_image)
    try:
        result = runner.run_script(
            script="apply.sh",
            configmaps={"service": "aws", "accelerator": "h100"},
            skip_system_operations=True
        )
        
        # Should exit successfully (even if system operations are skipped)
        assert_exit_code(result, 0)
    finally:
        runner.cleanup()

@pytest.mark.skip(reason="Skipping test_apply_aws_gb200. Kernel is flaky based on where it is run.")
def test_apply_aws_gb200(base_image):
    """Test apply.sh with aws-gb200 combination."""
    runner = DockerTestRunner(package="nvidia-setup", base_image=base_image)
    try:
        result = runner.run_script(
            script="apply.sh",
            configmaps={"service": "aws", "accelerator": "gb200"},
            skip_system_operations=True
        )
        
        assert_exit_code(result, 0)
    finally:
        runner.cleanup()


def test_apply_with_env_overrides(base_image):
    """Test apply.sh with environment variable overrides."""
    runner = DockerTestRunner(package="nvidia-setup", base_image=base_image)
    try:
        result = runner.run_script(
            script="apply.sh",
            configmaps={"service": "aws", "accelerator": "h100"},
            env_vars={
                "NVIDIA_KERNEL": "6.8.0",
                "NVIDIA_SETUP_KERNEL_ALLOW_NEWER": "true",  # container kernel may be newer than override
                "NVIDIA_EFA": "1.31.0",
                "NVIDIA_LUSTRE": "aws"
            },
            skip_system_operations=True
        )
        
        assert_exit_code(result, 0)
    finally:
        runner.cleanup()


def test_apply_missing_configmap():
    """Test apply.sh with missing configmap files."""
    runner = DockerTestRunner(package="nvidia-setup")
    try:
        # Run with empty configmaps to simulate missing files
        result = runner.run_script(
            script="apply.sh",
            configmaps={},
            skip_system_operations=True
        )
        
        # Should fail because service and accelerator are required
        assert_exit_code(result, 1)
    finally:
        runner.cleanup()


def test_apply_dynamic_supported_listing(base_image):
    """Test that apply.sh dynamically lists supported combinations from defaults directory."""
    runner = DockerTestRunner(package="nvidia-setup", base_image=base_image)
    try:
        result = runner.run_script(
            script="apply.sh",
            configmaps={"service": "invalid", "accelerator": "invalid"}
        )
        
        assert_exit_code(result, 1)
        # Should contain at least aws-h100 and aws-gb200 in the supported list
        assert_output_contains(result.stdout, "aws-h100")
        assert_output_contains(result.stdout, "aws-gb200")
    finally:
        runner.cleanup()


def test_apply_install_kernel_only_skips_actual_install(base_image):
    """With NVIDIA_SETUP_INSTALL_KERNEL=true and SKIP_SYSTEM_OPERATIONS, apply runs kernel-only path but skips real install/reboot."""
    runner = DockerTestRunner(package="nvidia-setup", base_image=base_image)
    try:
        result = runner.run_script(
            script="apply.sh",
            configmaps={"service": "aws", "accelerator": "h100"},
            env_vars={"NVIDIA_SETUP_INSTALL_KERNEL": "true"},
            skip_system_operations=True,
        )
        assert_exit_code(result, 0)
        assert_output_contains(result.stdout, "Skipping kernel install for test environment")
    finally:
        runner.cleanup()


def test_apply_install_kernel_only_aws_gb200_skips_actual_install(base_image):
    """Kernel-only path with aws-gb200; skips actual install when SKIP_SYSTEM_OPERATIONS set."""
    runner = DockerTestRunner(package="nvidia-setup", base_image=base_image)
    try:
        result = runner.run_script(
            script="apply.sh",
            configmaps={"service": "aws", "accelerator": "gb200"},
            env_vars={"NVIDIA_SETUP_INSTALL_KERNEL": "true"},
            skip_system_operations=True,
        )
        assert_exit_code(result, 0)
        assert_output_contains(result.stdout, "Skipping kernel install for test environment")
    finally:
        runner.cleanup()
