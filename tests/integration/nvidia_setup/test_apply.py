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


def test_apply_eks_h100(base_image):
    """Test apply.sh with eks-h100 combination."""
    runner = DockerTestRunner(package="nvidia-setup", base_image=base_image)
    try:
        result = runner.run_script(
            script="apply.sh",
            configmaps={"service": "eks", "accelerator": "h100"},
            skip_system_operations=True
        )
        
        # Should exit successfully (even if system operations are skipped)
        assert_exit_code(result, 0)
    finally:
        runner.cleanup()


def test_apply_eks_gb200(base_image):
    """Test apply.sh with eks-gb200 combination."""
    runner = DockerTestRunner(package="nvidia-setup", base_image=base_image)
    try:
        result = runner.run_script(
            script="apply.sh",
            configmaps={"service": "eks", "accelerator": "gb200"},
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
            configmaps={"service": "eks", "accelerator": "h100"},
            env_vars={
                "EIDOS_KERNEL": "6.8.0",
                "EIDOS_EFA": "1.31.0",
                "EIDOS_LUSTRE": "aws"
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
        # Should contain at least eks-h100 and eks-gb200 in the supported list
        assert_output_contains(result.stdout, "eks-h100")
        assert_output_contains(result.stdout, "eks-gb200")
    finally:
        runner.cleanup()
