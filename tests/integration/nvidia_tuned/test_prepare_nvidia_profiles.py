#!/usr/bin/env python3
"""
Tests for nvidia-tuned prepare_nvidia_profiles.sh script.

Tests verify:
- Tuned version meets OS-specific requirements (>= 2.15 for Ubuntu 22.04/Debian 11, >= 2.19 for others)
- prepare_nvidia_profiles does the right thing for all combinations of:
  - accelerator (h100, gb200)
  - intent (performance, inference, multiNodeTraining)
  - service (aws, none)
- For AWS service, verifies grub config file is created correctly
"""

import pytest
import re

from tests.helpers.assertions import (
    assert_exit_code,
    assert_output_contains,
)
from tests.helpers.docker_test import DockerTestRunner


def install_tuned_in_container(runner: DockerTestRunner, base_image: str):
    """Install tuned package in an existing container."""
    if runner.container is None:
        raise RuntimeError("Container must be created before installing tuned. Call run_script first.")
    
    # Determine package manager based on base image
    if "ubuntu" in base_image or "debian" in base_image:
        # Update package lists and install tuned
        runner.container.exec_run(
            ["apt-get", "update", "-y"],
            workdir="/"
        )
        runner.container.exec_run(
            ["apt-get", "install", "-y", "tuned"],
            workdir="/"
        )
    elif "rocky" in base_image or "rhel" in base_image or "centos" in base_image:
        # For RHEL-based systems, use dnf if available, otherwise yum
        # Try dnf first (Rocky 9 uses dnf)
        dnf_result = runner.container.exec_run(
            ["which", "dnf"],
            workdir="/"
        )
        if dnf_result.exit_code == 0:
            runner.container.exec_run(
                ["dnf", "install", "-y", "tuned"],
                workdir="/"
            )
        else:
            runner.container.exec_run(
                ["yum", "install", "-y", "tuned"],
                workdir="/"
            )
    else:
        raise ValueError(f"Unknown base image: {base_image}")


def verify_tuned_version(runner: DockerTestRunner, base_image: str):
    """Verify tuned version meets OS-specific requirement."""
    # Determine required version based on OS
    # These dont have the calc_iso_cpus function in their profile so only need 2.15
    if "ubuntu:22.04" in base_image or "debian:11" in base_image:
        required_major = 2
        required_minor = 15
    elif "ubuntu:24.04" in base_image or "debian:12" in base_image or "rocky:9" in base_image or "rockylinux:9" in base_image:
        required_major = 2
        required_minor = 19
    else:
        # Default to 2.19 for unknown OS
        required_major = 2
        required_minor = 19
    
    # Ensure container is initialized
    if runner.container is None:
        raise RuntimeError("Container not initialized. Call install_tuned_in_container first.")
    
    result = runner.container.exec_run(
        ["tuned", "--version"],
        workdir="/"
    )
    
    assert_exit_code(result, 0)
    output = result.output.decode('utf-8', errors='replace')
    
    # Extract version number (format: "tuned 2.20.0")
    version_match = re.search(r'tuned\s+(\d+)\.(\d+)', output)
    assert version_match is not None, f"Could not parse tuned version from: {output}"
    
    major = int(version_match.group(1))
    minor = int(version_match.group(2))
    
    assert major > required_major or (major == required_major and minor >= required_minor), \
        f"tuned version {major}.{minor} is less than required {required_major}.{required_minor} for {base_image}"


def create_container_for_testing(runner: DockerTestRunner, configmaps: dict):
    """Create a container for testing without running scripts."""
    import tempfile
    import shutil
    from pathlib import Path
    
    # Use the same approach as run_script but don't execute the script
    # Set up package environment
    temp_dir = tempfile.mkdtemp(prefix="skyhook-test-")
    runner.temp_dir = temp_dir
    skyhook_package_dir = Path(temp_dir) / "skyhook-package"
    
    # Copy entire package directory structure
    shutil.copytree(runner._package_path, skyhook_package_dir, dirs_exist_ok=True)
    
    # Create configmaps directory and write configmaps
    configmaps_dir = skyhook_package_dir / "configmaps"
    configmaps_dir.mkdir(parents=True, exist_ok=True)
    
    if configmaps:
        for key, value in configmaps.items():
            configmap_file = configmaps_dir / key
            configmap_file.write_text(value)
    
    # Create node-metadata directory
    node_metadata_dir = skyhook_package_dir / "node-metadata"
    node_metadata_dir.mkdir(parents=True, exist_ok=True)
    
    # Set up environment variables
    container_env = {
        "SKYHOOK_DIR": "/skyhook-package",
        "STEP_ROOT": "/skyhook-package/skyhook_dir",
    }
    
    # Create container with bind mount
    runner.container = runner.client.containers.run(
        runner.base_image,
        command=["/bin/bash", "-c", "tail -f /dev/null"],  # Keep container running
        detach=True,
        environment=container_env,
        volumes={
            str(skyhook_package_dir): {
                "bind": "/skyhook-package",
                "mode": "rw"
            }
        },
        remove=False,
        tty=False,
        stdin_open=False
    )
    
    # Wait for container to be ready
    import time
    time.sleep(1)


def run_script_in_container(runner: DockerTestRunner, script: str, configmaps: dict):
    """Run a script in an existing container with given configmaps."""
    if runner.container is None:
        raise RuntimeError("Container must exist before running script")
    
    # Update configmaps in the container
    configmap_cmds = []
    for key, value in configmaps.items():
        # Escape single quotes in values
        escaped_value = value.replace("'", "'\"'\"'")
        configmap_cmds.append(f"echo '{escaped_value}' > /skyhook-package/configmaps/{key}")
    
    runner.container.exec_run(
        ["bash", "-c", f"mkdir -p /skyhook-package/configmaps && {' && '.join(configmap_cmds)}"],
        workdir="/"
    )
    
    # Run the script in the existing container
    script_path = f"/skyhook-package/skyhook_dir/{script}"
    container_env = {
        "SKYHOOK_DIR": "/skyhook-package",
        "STEP_ROOT": "/skyhook-package/skyhook_dir",
        "SKIP_SYSTEM_OPERATIONS": "true",
    }
    
    cmd = f"bash {script_path} 2>&1"
    exec_result = runner.container.exec_run(
        ["/bin/bash", "-c", cmd],
        workdir="/skyhook-package",
        environment=container_env
    )
    
    # Create a TestResult-like object
    class TestResult:
        def __init__(self, exit_code, stdout, stderr=""):
            self.exit_code = exit_code
            self.stdout = stdout
            self.stderr = stderr
    
    return TestResult(
        exec_result.exit_code,
        exec_result.output.decode('utf-8', errors='replace'),
        ""
    )


def test_tuned_version_requirement(base_image):
    """Test that tuned version meets OS-specific requirement (>= 2.15 for Ubuntu 22.04/Debian 11, >= 2.19 for others)."""
    runner = DockerTestRunner(package="nvidia-tuned", base_image=base_image)
    try:
        # Create container directly
        create_container_for_testing(runner, {"accelerator": "h100"})
        # Install tuned
        install_tuned_in_container(runner, base_image)
        verify_tuned_version(runner, base_image)
    finally:
        runner.cleanup()


@pytest.mark.parametrize("accelerator", ["h100", "gb200"])
@pytest.mark.parametrize("intent", ["performance", "inference", "multiNodeTraining"])
def test_prepare_nvidia_profiles_no_service(base_image, accelerator, intent):
    """Test prepare_nvidia_profiles with all accelerator/intent combinations without service."""
    runner = DockerTestRunner(package="nvidia-tuned", base_image=base_image)
    try:
        configmaps = {
            "accelerator": accelerator,
            "intent": intent,
        }
        
        # Create container directly (faster than running script first)
        create_container_for_testing(runner, configmaps)
        
        # Install tuned in the container
        install_tuned_in_container(runner, base_image)
        
        # Now run the script in the same container
        result = run_script_in_container(runner, "prepare_nvidia_profiles.sh", configmaps)
        
        assert_exit_code(result, 0)
        
        # Verify profile name is constructed correctly
        expected_profile = f"nvidia-{accelerator}-{intent}"
        assert_output_contains(result.stdout, expected_profile)
        
        # Verify profile was written to configmap
        tuned_profile_content = runner.get_file_contents(
            "/skyhook-package/configmaps/tuned_profile"
        )
        assert expected_profile in tuned_profile_content, \
            f"Expected profile {expected_profile} not found in tuned_profile file"
        
        # Verify profile directory exists in /etc/tuned
        profile_exists = runner.file_exists(f"/etc/tuned/{expected_profile}/tuned.conf")
        assert profile_exists, \
            f"Profile {expected_profile} was not deployed to /etc/tuned/"
        
    finally:
        runner.cleanup()


@pytest.mark.parametrize("accelerator", ["h100", "gb200"])
@pytest.mark.parametrize("intent", ["performance", "inference", "multiNodeTraining"])
def test_prepare_nvidia_profiles_with_aws_service(base_image, accelerator, intent):
    """Test prepare_nvidia_profiles with AWS service for all combinations."""
    runner = DockerTestRunner(package="nvidia-tuned", base_image=base_image)
    try:
        configmaps = {
            "accelerator": accelerator,
            "intent": intent,
            "service": "aws",
        }
        
        # Create container by running script (this creates the container)
        try:
            runner.run_script(
                script="prepare_nvidia_profiles.sh",
                configmaps=configmaps,
                skip_system_operations=True
            )
        except Exception:
            # Script may fail, but container should be created
            pass
        
        # Ensure container exists
        if runner.container is None:
            raise RuntimeError("Container was not created by run_script")
        
        # Install tuned in the existing container
        install_tuned_in_container(runner, base_image)
        
        # Now run the script in the same container
        result = run_script_in_container(runner, "prepare_nvidia_profiles.sh", configmaps)
        
        assert_exit_code(result, 0)
        
        # Verify service profile was created
        expected_profile = f"nvidia-{accelerator}-{intent}"
        assert_output_contains(result.stdout, "Requested service: aws")
        assert_output_contains(result.stdout, f"include={expected_profile}")
        
        # Verify service profile directory exists
        service_profile_exists = runner.file_exists("/etc/tuned/aws/tuned.conf")
        assert service_profile_exists, "AWS service profile was not deployed"
        
        # Verify service profile includes the workload profile
        service_profile_content = runner.get_file_contents("/etc/tuned/aws/tuned.conf")
        assert f"include={expected_profile}" in service_profile_content, \
            f"AWS profile does not include {expected_profile}"
        
        # Verify tuned_profile file points to service
        tuned_profile_content = runner.get_file_contents(
            "/skyhook-package/configmaps/tuned_profile"
        )
        assert "aws" in tuned_profile_content, \
            "tuned_profile should point to 'aws' service profile"
        
        # For AWS, verify bootloader script exists
        bootloader_script_exists = runner.file_exists("/etc/tuned/aws/bootloader.sh")
        assert bootloader_script_exists, "AWS bootloader.sh script was not deployed"
        
        # Verify script.sh exists
        script_exists = runner.file_exists("/etc/tuned/aws/script.sh")
        assert script_exists, "AWS script.sh was not deployed"
        
    finally:
        runner.cleanup()


def test_prepare_nvidia_profiles_aws_grub_config(base_image):
    """Test that AWS service creates the correct grub config file."""
    runner = DockerTestRunner(package="nvidia-tuned", base_image=base_image)
    try:
        configmaps = {
            "accelerator": "h100",
            "intent": "inference",
            "service": "aws",
        }
        
        # Create container directly
        create_container_for_testing(runner, configmaps)
        
        # Install tuned in the container
        install_tuned_in_container(runner, base_image)
        
        # Install grub-common for update-grub command (if available)
        if "ubuntu" in base_image or "debian" in base_image:
            runner.container.exec_run(
                ["apt-get", "install", "-y", "grub-common", "grub2-common"],
                workdir="/"
            )
        
        # Run prepare_nvidia_profiles in the same container
        result = run_script_in_container(runner, "prepare_nvidia_profiles.sh", configmaps)
        assert_exit_code(result, 0)
        
        # Create a mock /etc/tuned/bootcmdline file to simulate tuned writing it
        # Note: The bootcmdline file should contain the boot parameters as text
        runner.container.exec_run(
            ["bash", "-c", "mkdir -p /etc/tuned && echo 'TUNED_BOOT_CMDLINE=\"iommu=pt hugepages=8192\"' > /etc/tuned/bootcmdline"],
            workdir="/"
        )
        
        # Run the AWS bootloader script (skip update-grub if it fails)
        bootloader_result = runner.container.exec_run(
            ["bash", "-c", "/etc/tuned/aws/bootloader.sh || true"],
            workdir="/"
        )
        
        # Verify grub config file was created
        grub_config_exists = runner.file_exists("/etc/default/grub.d/99_tuned.cfg")
        assert grub_config_exists, "Grub config file 99_tuned.cfg was not created"
        
        # Verify grub config file content
        grub_config_content = runner.get_file_contents("/etc/default/grub.d/99_tuned.cfg")
        assert "/etc/tuned/bootcmdline" in grub_config_content, \
            "Grub config should reference /etc/tuned/bootcmdline"
        assert "GRUB_CMDLINE_LINUX_DEFAULT" in grub_config_content, \
            "Grub config should set GRUB_CMDLINE_LINUX_DEFAULT"
        # The implementation sources the bootcmdline file and uses TUNED_BOOT_CMDLINE
        assert "TUNED_BOOT_CMDLINE" in grub_config_content, \
            "Grub config should use TUNED_BOOT_CMDLINE variable"
        
    finally:
        runner.cleanup()


def test_prepare_nvidia_profiles_default_intent(base_image):
    """Test that default intent is 'performance' when not specified."""
    runner = DockerTestRunner(package="nvidia-tuned", base_image=base_image)
    try:
        configmaps = {
            "accelerator": "h100",
            # No intent specified
        }
        
        # Create container directly
        create_container_for_testing(runner, configmaps)
        
        # Install tuned in the container
        install_tuned_in_container(runner, base_image)
        
        # Run the script in the same container
        result = run_script_in_container(runner, "prepare_nvidia_profiles.sh", configmaps)
        
        assert_exit_code(result, 0)
        assert_output_contains(result.stdout, "No intent specified, defaulting to: performance")
        assert_output_contains(result.stdout, "nvidia-h100-performance")
        
    finally:
        runner.cleanup()


def test_prepare_nvidia_profiles_missing_accelerator(base_image):
    """Test that missing accelerator configmap causes error."""
    runner = DockerTestRunner(package="nvidia-tuned", base_image=base_image)
    try:
        configmaps = {
            "intent": "performance",
            # No accelerator specified
        }
        
        # Create container directly
        create_container_for_testing(runner, configmaps)
        
        # Install tuned in the container
        install_tuned_in_container(runner, base_image)
        
        # Run the script in the same container
        result = run_script_in_container(runner, "prepare_nvidia_profiles.sh", configmaps)
        
        assert_exit_code(result, 1)
        assert_output_contains(result.stdout, "accelerator configmap not found")
        
    finally:
        runner.cleanup()


def test_prepare_nvidia_profiles_aws_service_specific_profile(base_image):
    """Test that AWS service-specific inference profiles are used when available."""
    runner = DockerTestRunner(package="nvidia-tuned", base_image=base_image)
    try:
        configmaps = {
            "accelerator": "h100",
            "intent": "inference",
            "service": "aws",
        }
        
        # Create container directly
        create_container_for_testing(runner, configmaps)
        
        # Install tuned in the container
        install_tuned_in_container(runner, base_image)
        
        # Run the script in the same container
        result = run_script_in_container(runner, "prepare_nvidia_profiles.sh", configmaps)
        
        assert_exit_code(result, 0)
        
        # Verify that AWS-specific inference profile was deployed
        # (it should overwrite the OS profile)
        inference_profile_content = runner.get_file_contents(
            "/etc/tuned/nvidia-h100-inference/tuned.conf"
        )
        
        # AWS-specific profile should NOT have scheduler parameters set (they may be in comments)
        # Check that they're not set as actual sysctl parameters (not commented out)
        import re
        
        # Check for uncommented kernel.sched_latency_ns= lines
        latency_pattern = r'^\s*kernel\.sched_latency_ns\s*='
        assert not re.search(latency_pattern, inference_profile_content, re.MULTILINE), \
            "AWS-specific inference profile should not contain uncommented kernel.sched_latency_ns"
        
        # Check for uncommented kernel.sched_min_granularity_ns= lines
        granularity_pattern = r'^\s*kernel\.sched_min_granularity_ns\s*='
        assert not re.search(granularity_pattern, inference_profile_content, re.MULTILINE), \
            "AWS-specific inference profile should not contain uncommented kernel.sched_min_granularity_ns"
        
        # But should have vm.swappiness
        assert "vm.swappiness=1" in inference_profile_content, \
            "AWS-specific inference profile should contain vm.swappiness=1"
        
    finally:
        runner.cleanup()


def test_prepare_nvidia_profiles_common_profiles_deployed(base_image):
    """Test that common base profiles are deployed to /usr/lib/tuned/."""
    runner = DockerTestRunner(package="nvidia-tuned", base_image=base_image)
    try:
        configmaps = {
            "accelerator": "h100",
            "intent": "performance",
        }
        
        # Create container directly
        create_container_for_testing(runner, configmaps)
        
        # Install tuned in the container
        install_tuned_in_container(runner, base_image)
        
        # Run the script in the same container
        result = run_script_in_container(runner, "prepare_nvidia_profiles.sh", configmaps)
        
        assert_exit_code(result, 0)
        
        # Verify common profiles are deployed
        nvidia_base_exists = runner.file_exists("/usr/lib/tuned/nvidia-base/tuned.conf")
        assert nvidia_base_exists, "nvidia-base profile was not deployed to /usr/lib/tuned/"
        
        nvidia_acs_disable_exists = runner.file_exists("/usr/lib/tuned/nvidia-acs-disable/tuned.conf")
        assert nvidia_acs_disable_exists, "nvidia-acs-disable profile was not deployed to /usr/lib/tuned/"
        
    finally:
        runner.cleanup()
