# nvidia-setup package tests

"""
Test matrix configuration for nvidia-setup package.

Define the containers/base images to test against.
Each entry can be a string (base image name) or a dict with additional config.
"""

# Test matrix: list of base images to test against
TEST_MATRIX = [
   # "ubuntu:22.04",  # Jammy - matches current defaults
    # "ubuntu:20.04",  # Focal - if needed
    "ubuntu:24.04",  # Noble - if needed
]

# Alternative: more detailed configuration
# TEST_MATRIX = [
#     {
#         "base_image": "ubuntu:22.04",
#         "name": "jammy",
#         "description": "Ubuntu 22.04 Jammy Jellyfish"
#     },
#     {
#         "base_image": "ubuntu:20.04",
#         "name": "focal",
#         "description": "Ubuntu 20.04 Focal Fossa"
#     },
# ]
