# nvidia-tuned package tests

"""
Test matrix configuration for nvidia-tuned package.

Define the containers/base images to test against.
Each entry can be a string (base image name) or a dict with additional config.
"""

# Test matrix: list of base images to test against
TEST_MATRIX = [
    "ubuntu:24.04",  # Noble
    "ubuntu:22.04",  # Jammy
    "debian:12",     # Bookworm
    "rockylinux:9",  # Rocky Linux 9
]
