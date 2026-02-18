"""
Tests for shellscript package.

Test matrix: Run tests against multiple base images.
"""
TEST_MATRIX = [
    "ubuntu:22.04",  # Jammy
    "ubuntu:24.04",  # Noble
    "rockylinux:9",  # Rocky Linux 9
]
