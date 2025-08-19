# Skyhook Packages

This repository contains pre-built packages for the [NVIDIA Skyhook Operator](https://github.com/NVIDIA/skyhook), a Kubernetes-aware package manager for cluster administrators to safely modify and maintain underlying hosts declaratively at scale.

## Overview

Skyhook packages follow a well-defined lifecycle with multiple stages (apply, config, interrupt, post-interrupt, upgrade, uninstall) that ensure proper installation, configuration, and management of node-level changes. Each package in this repository implements these lifecycle stages according to its specific purpose.

For detailed information about package lifecycle stages, see [PACKAGE_LIFECYCLE.md](./PACKAGE_LIFECYCLE.md).

## Available Packages

### 1. Shellscript Package (`shellscript/`)
A versatile package that allows you to run arbitrary bash scripts defined in your Skyhook Custom Resource configMaps.

**Capabilities:**
- Execute custom bash scripts during any lifecycle stage
- Full lifecycle support (apply, config, post-interrupt, uninstall with checks)
- Configurable through configMaps
- Useful for custom automation and system modifications

**Example use cases:**
- Custom software installation
- System configuration changes
- File management operations
- Service management tasks

### 2. Tuning Package (`tuning/`)
A specialized package for system-level tuning and configuration management.

**Capabilities:**
- System service configuration via drop-in files
- Kernel parameter tuning (sysctl)
- User limit configuration (ulimits)
- Container runtime limit configuration
- GRUB configuration management
- Support for different interrupt types based on configuration changes

**Supported configuration types:**
- `grub.conf` - GRUB kernel parameters (requires reboot)
- `sysctl.conf` - Kernel parameters (requires reboot or service restart)
- `ulimit.conf` - User limits (immediate effect + container limits on reboot)
- `service_{name}.conf` - Systemd service configurations (requires service restart)

### 3. Tuned Package (`tuned/`)
A package for managing the tuned system tuning daemon on Linux systems for automated performance optimization.

**Capabilities:**
- Multi-distribution support (Ubuntu/Debian, CentOS/RHEL/Amazon Linux, Fedora)
- Automated tuned package installation and service management
- Custom tuned profile deployment via configmaps
- Built-in profile validation and verification
- Handles necessary interrupts for tuning parameters that require reboots/restarts
- Comprehensive installation and configuration validation

**Key features:**
- Deploy custom tuned profiles from configmaps
- Apply system-wide performance tuning profiles
- Automatic service lifecycle management (install, configure, validate, uninstall)
- Support for built-in profiles (balanced, powersave, throughput-performance, etc.)
- Idempotent operations safe for repeated execution

## Package Structure

Each package follows the standard skyhook package structure:

```
[package name]
├── Dockerfile
├── config.json
├── README.md
├── root_dir/
│   └── ... (files copied to root filesystem)
└── skyhook_dir/
    └── ... (scripts and static files used by package)
```

### Key Components

- **`skyhook_dir/`**: Contains scripts used in lifecycle stages and any static files referenced by scripts
- **`root_dir/`**: Files copied directly to the root filesystem (e.g., `/etc/hosts` configurations)
- **`config.json`**: Package configuration that must comply with the [skyhook agent schemas v1](https://github.com/NVIDIA/skyhook/tree/main/agent/skyhook-agent/src/skyhook_agent/schemas/v1)
- **`Dockerfile`**: Copies package components to `/skyhook-package` in the container

## Building Packages

To build a package for multi-architecture deployment:

1. Create a builder instance:
   ```bash
   docker buildx create --name builder --use
   ```

2. Build and push the package:
   ```bash
   docker buildx build -t {package}:{tag} \
     -f {dockerfile} \
     --platform=linux/amd64,linux/arm64 \
     --push {package_directory}
   ```

Example:
```bash
docker buildx build -t ghcr.io/nvidia/skyhook-packages/shellscript:1.1.1 \
  -f shellscript/Dockerfile \
  --platform=linux/amd64,linux/arm64 \
  --push shellscript/
```

## Using Packages

Packages are used by creating Skyhook Custom Resources (SCRs) that reference the package images. Here's a basic example:

```yaml
apiVersion: skyhook.nvidia.com/v1alpha1
kind: Skyhook
metadata:
  name: example-package
spec:
  nodeSelectors:
    matchLabels:
      skyhook.nvidia.com/node-type: worker
  packages:
    my-package:
      version: 1.1.1
      image: ghcr.io/nvidia/skyhook-packages/shellscript:1.1.1
      configMap:
        apply.sh: |
          #!/bin/bash
          echo "Package applied successfully"
        apply_check.sh: |
          #!/bin/bash
          echo "Package installation verified"
```

For detailed usage examples, see the README files in each package directory.

## Package Lifecycle

All packages in this repository implement the skyhook lifecycle stages:

1. **Apply** - Initial installation and setup
2. **Config** - Handle configuration changes
3. **Interrupt** - Handle service restarts/reboots when needed
4. **Post-Interrupt** - Validation after interrupts
5. **Upgrade** - Handle version upgrades
6. **Uninstall** - Clean removal of components

The lifecycle ensures that packages are applied safely with minimal disruption to running workloads. See [PACKAGE_LIFECYCLE.md](./PACKAGE_LIFECYCLE.md) for comprehensive documentation.

## Repository Rules

This repository follows strict development practices:

### Commit Format
All commits MUST use conventional commit format with the package name as scope:

- `feat(shellscript): Add support for upgrade stage`
- `fix(tuning): Post-interrupt check for containerd changes did not allow infinity setting`
- `docs(general/ci): Update the main README.md for CI workflow`

### Versioning
- Package versions MUST follow [Semantic Versioning](https://semver.org/)
- Tags are package-specific: `{package}/{version}` (e.g., `shellscript/1.1.1`)
- CI automatically builds packages on tag creation

### Development Workflow
1. Make changes to package code and configuration
2. Update package version in `config.json`
3. **Validate package configuration** against the [official schemas](https://github.com/NVIDIA/skyhook/tree/main/agent/skyhook-agent/src/skyhook_agent/schemas/v1)
4. Test package functionality
5. Commit with conventional format
6. Create version tag
7. CI builds and publishes package automatically

### Schema Validation

All packages must have a valid `config.json` that complies with the skyhook agent JSON schemas. The skyhook-agent includes built-in validation tooling:

```bash
# Validate your package configuration before publishing
skyhook-agent validate /path/to/your/config.json
```

This validation step is crucial as the agent uses JSON schema validation to ensure package configurations are correct before execution.

## Getting Started

1. **Choose a package** that fits your use case:
   - `shellscript` for custom scripts and automation
   - `tuning` for system-level configuration management  
   - `tuned` for automated performance tuning with the tuned daemon
2. **Review the package README** for specific usage instructions and examples
3. **Create a Skyhook Custom Resource** referencing the package
4. **Apply the SCR** to your cluster and monitor the package deployment
5. **Verify the package status** using `kubectl describe skyhooks`

## Documentation

- [Package Lifecycle Documentation](./PACKAGE_LIFECYCLE.md) - Comprehensive guide to package lifecycle stages
- [Shellscript Package](./shellscript/README.md) - Usage guide for the shellscript package
- [Tuning Package](./tuning/README.md) - Usage guide for the tuning package
- [Tuned Package](./tuned/README.md) - Usage guide for the tuned package
- [NVIDIA Skyhook Documentation](https://github.com/NVIDIA/skyhook) - Main skyhook operator documentation

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on contributing to this repository.

## License

This project is licensed under the terms specified in [LICENSE](./LICENSE).