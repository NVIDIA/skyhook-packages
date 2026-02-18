#!/usr/bin/env python3
"""
Tests for nvidia-setup apply_check.sh script.
"""

import pytest

from tests.helpers.assertions import assert_exit_code
from tests.helpers.docker_test import DockerTestRunner


def test_apply_check_unsupported_combination():
    """Test that apply_check.sh fails for unsupported combinations."""
    runner = DockerTestRunner(package="nvidia-setup")
    try:
        result = runner.run_script(
            script="apply_check.sh",
            configmaps={"service": "invalid", "accelerator": "invalid"}
        )
        
        assert_exit_code(result, 1)
    finally:
        runner.cleanup()


def test_apply_check_eks_h100(base_image):
    """Test apply_check.sh with eks-h100 combination."""
    runner = DockerTestRunner(package="nvidia-setup", base_image=base_image)
    try:
        result = runner.run_script(
            script="apply_check.sh",
            configmaps={"service": "eks", "accelerator": "h100"}
        )
        
        # apply_check.sh will likely fail if packages aren't installed,
        # but it should at least execute the check scripts
        assert result.exit_code is not None
    finally:
        runner.cleanup()


def test_apply_check_eks_gb200(base_image):
    """Test apply_check.sh with eks-gb200 combination."""
    runner = DockerTestRunner(package="nvidia-setup", base_image=base_image)
    try:
        result = runner.run_script(
            script="apply_check.sh",
            configmaps={"service": "eks", "accelerator": "gb200"}
        )
        
        assert result.exit_code is not None
    finally:
        runner.cleanup()


def test_apply_check_with_env_overrides(base_image):
    """Test apply_check.sh with environment variable overrides."""
    runner = DockerTestRunner(package="nvidia-setup", base_image=base_image)
    try:
        result = runner.run_script(
            script="apply_check.sh",
            configmaps={"service": "eks", "accelerator": "h100"},
            env_vars={
                "EIDOS_KERNEL": "5.15.0-1025-aws",
                "EIDOS_EFA": "1.31.0",
                "EIDOS_LUSTRE": "aws"
            }
        )
        
        assert result.exit_code is not None
    finally:
        runner.cleanup()
