# NVIDIA Tuned Package

A Skyhook package that extends the base `tuned` package with NVIDIA-specific performance profiles for GPU and DGX systems.

## Overview

This package inherits from the base `tuned` package and adds pre-configured tuned profiles optimized for NVIDIA hardware. The profiles are automatically deployed to `/etc/tuned/` on the host filesystem, making them immediately available for use.


## How It Works

This package uses the `root_dir/` mechanism to pre-stage tuned profiles on the host filesystem:

1. **Package initialization**: The skyhook agent extracts `root_dir/` contents to the host root filesystem
2. **Apply stage**: The inherited `tuned` package installs and enables the tuned service
3. **Config stage**: Users can select any pre-bundled NVIDIA profile via the `tuned_profile` configmap

The profiles are available immediately after package extraction, before the tuned service is even installed.

## Usage

### Basic Usage with NVIDIA Profile

```yaml
apiVersion: skyhook.nvidia.com/v1alpha1
kind: Skyhook
metadata:
  name: nvidia-tuned-example
spec:
  nodeSelectors:
    matchLabels:
      node-type: gpu-worker
  packages:
    nvidia-tuned:
      image: ghcr.io/nvidia/skyhook-packages/nvidia_tuned:1.0.0
      version: 1.0.0
      configMap:
        tuned_profile: nvidia-h100-performance
```

### DGX Throughput Profile with Reboot

For profiles that modify kernel parameters requiring a reboot:

```yaml
apiVersion: skyhook.nvidia.com/v1alpha1
kind: Skyhook
metadata:
  name: dgx-tuned-example
spec:
  nodeSelectors:
    matchLabels:
      nvidia.com/dgx: "true"
  packages:
    nvidia-tuned:
      image: ghcr.io/nvidia/skyhook-packages/nvidia_tuned:1.0.0
      version: 1.0.0
      interrupt:
        type: reboot
      configInterrupts:
        tuned_profile:
          type: reboot
      env:
        - name: INTERRUPT
          value: "true"
      configMap:
        tuned_profile: nvidia-h100-performance
```

### Multiple Profiles

You can apply multiple profiles simultaneously by space-separating them. Tuned will merge the settings from all specified profiles:

```yaml
configMap:
  tuned_profile: nvidia-h100-performance nvidia-aws
```

When using multiple profiles, settings from later profiles override earlier ones where they conflict.

### Combining with Custom Profiles

You can still use custom profiles alongside the pre-bundled ones:

```yaml
configMap:
  tuned_profile: my-custom-profile
  my-custom-profile: |-
    [main]
    summary=Custom profile including NVIDIA optimizations
    include=nvidia-gpu-optimized
    
    [sysctl]
    # Additional custom settings
    net.core.somaxconn=65535
```

## Verification

After deployment, verify the profile is active:

```bash
# List available profiles (should include nvidia-* profiles)
tuned-adm list

# Check active profile
tuned-adm active

# Verify tuning is applied
tuned-adm verify
```

## Inheritance

This package inherits all functionality from the base `tuned` package:

- Multi-distribution support (Ubuntu/Debian, CentOS/RHEL/Amazon Linux, Fedora)
- Custom profile deployment via configmaps
- Script deployment for complex tuning logic
- Full lifecycle management (install, configure, uninstall)

See the [tuned package README](../tuned/README.md) for complete documentation on all features.

## Version

- **Package Version**: 1.0.0
- **Base Package**: tuned:1.2.0
- **Schema Version**: v1
