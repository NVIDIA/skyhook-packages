#!/usr/bin/env python3

# SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Validation Script for Skyhook Packages

This script validates a config.json file against the skyhook-agent schema
and verifies that all referenced step files exist.
It is designed to run in the distroless skyhook-agent container.
"""

import json
import sys
import os
from jsonschema import ValidationError

try:
    from skyhook_agent import config
except ImportError as e:
    print(f"ERROR: Failed to import skyhook_agent.config: {e}", file=sys.stderr)
    print("This script must be run in the skyhook-agent container.", file=sys.stderr)
    sys.exit(1)


def validate_config_file(config_path: str) -> bool:
    """
    Validate a config.json file against the skyhook-agent schema and verify step files exist.
    
    Args:
        config_path: Path to the config.json file to validate
        
    Returns:
        True if validation succeeds, False otherwise
    """
    # Check if file exists
    if not os.path.exists(config_path):
        print(f"ERROR: Config file not found: {config_path}", file=sys.stderr)
        return False
    
    # Load JSON file
    try:
        with open(config_path, 'r') as f:
            config_data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in {config_path}: {e}", file=sys.stderr)
        return False
    except IOError as e:
        print(f"ERROR: Failed to read {config_path}: {e}", file=sys.stderr)
        return False
    
    # Determine step_root_dir based on config.json location
    # config.json is at <package-dir>/config.json
    # skyhook_dir is at <package-dir>/skyhook_dir
    # In the container at runtime, this becomes /skyhook-package/skyhook_dir
    config_dir = os.path.dirname(os.path.abspath(config_path))
    skyhook_dir = os.path.join(config_dir, 'skyhook_dir')
    
    # Use /skyhook-package/skyhook_dir as requested by the user
    # This is the path structure used in the container at runtime
    # For validation, we use the actual filesystem path where files exist
    # since step.Steps.validate() uses os.path.exists() to check files
    step_root_dir = os.path.abspath(skyhook_dir)
    
    # Validate using config.load() which validates schema and step files
    try:
        # config.load() validates the schema, migrates if needed, and validates step files exist
        config.load(config_data, step_root_dir=step_root_dir)
        
        print(f"✓ Validation successful: {config_path}")
        print(f"  Schema validation: passed")
        print(f"  Step files validation: passed")
        return True
        
    except ValidationError as e:
        print(f"ERROR: Schema validation failed for {config_path}:", file=sys.stderr)
        print(f"  {e.message}", file=sys.stderr)
        if e.absolute_path:
            print(f"  Path: {'.'.join(str(p) for p in e.absolute_path)}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"ERROR: Validation failed for {config_path}: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return False


def main():
    """Main entry point for the validation script."""
    if len(sys.argv) != 2:
        print("Usage: validate.py <config.json>", file=sys.stderr)
        sys.exit(1)
    
    config_path = sys.argv[1]
    
    # Validate the config file
    if validate_config_file(config_path):
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
