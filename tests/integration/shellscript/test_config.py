#!/usr/bin/env python3
"""
Tests for shellscript package config mode.
"""

import pytest

from tests.helpers.assertions import assert_exit_code, assert_output_contains
from tests.helpers.docker_test import DockerTestRunner


def test_config_success(base_image):
    """Test config mode with a successful config script."""
    runner = DockerTestRunner(package="shellscript", base_image=base_image)
    try:
        result = runner.run_script(
            script="shellscript_run.sh",
            script_args=["config"],
            configmaps={
                "config.sh": """#!/bin/bash
echo "Config script executed"
exit 0
"""
            }
        )
        
        assert_exit_code(result, 0)
        assert_output_contains(result.stdout, "Config script executed")
    finally:
        runner.cleanup()


def test_config_missing_script(base_image):
    """Test config mode when script is missing."""
    runner = DockerTestRunner(package="shellscript", base_image=base_image)
    try:
        result = runner.run_script(
            script="shellscript_run.sh",
            script_args=["config"],
            configmaps={}  # No config.sh
        )
        
        # shellscript_run.sh doesn't exit with error, just prints message
        assert_exit_code(result, 0)
        assert_output_contains(result.stdout, "Could not find file")
        assert_output_contains(result.stdout, "config.sh")
    finally:
        runner.cleanup()
