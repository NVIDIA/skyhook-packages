# NVIDIA Tuned Package

A Skyhook package that extends the base `tuned` package with NVIDIA-specific performance profiles for GPU and DGX systems.

## Overview

This package inherits from the base `tuned` package and adds pre-configured tuned profiles optimized for NVIDIA hardware. The profiles are organized by:

- **Common base profiles**: Foundational settings deployed to `/usr/lib/tuned/`
- **OS-specific workload profiles**: Profiles that may vary by OS version
- **Cloud provider profiles**: Provider-specific settings (AWS, GCP, etc.)

## Directory Structure

```
skyhook_dir/
├── profiles/
│   ├── common/                  # Base profiles → /usr/lib/tuned/
│   │   ├── nvidia-base/
│   │   └── nvidia-acs-disable/
│   ├── os/
│   │   ├── common/              # Default workload profiles
│   │   │   ├── nvidia-h100-performance/
│   │   │   ├── nvidia-h100-inference/
│   │   │   └── nvidia-h100-multiNodeTraining/
│   │   ├── ubuntu/
│   │   │   ├── 22.04/          # Symlinks to os/common/ (override when needed)
│   │   │   └── 24.04/
│   │   └── rhel/
│   │       └── 9/
│   └── cloud/
│       └── aws/
│           ├── tuned.conf.template  # Provider template (include= added dynamically)
│           └── script.sh
├── prepare_nvidia_profiles.sh
└── prepare_nvidia_profiles_check.sh
```

Note: Profiles are stored in `skyhook_dir/profiles/` (not `root_dir/`) to avoid polluting the host filesystem during package extraction. The prepare scripts explicitly copy profiles to the appropriate tuned directories.

## How It Works

1. **Prepare stage**: `prepare_nvidia_profiles.sh` runs:
   - Deploys common base profiles to `/usr/lib/tuned/`
   - Detects OS from `/etc/os-release`
   - Copies the appropriate OS-specific workload profile to `/etc/tuned/`
   - If a provider is specified, creates provider profile with dynamic `include=` pointing to the workload profile

2. **Config stage**: The inherited `tuned` package applies the configured profile

### Inheritance Chain

When you specify `profile: nvidia-h100-inference` and `provider: aws`:

```
aws (active profile)
  └── includes: nvidia-h100-inference
        └── includes: nvidia-h100-performance
              └── includes: nvidia-base, nvidia-acs-disable
```

## Usage

### Basic Usage (No Cloud Provider)

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
        profile: nvidia-h100-performance
```

### With Cloud Provider (e.g., AWS)

```yaml
apiVersion: skyhook.nvidia.com/v1alpha1
kind: Skyhook
metadata:
  name: nvidia-tuned-aws
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
        profile:
          type: reboot
      env:
        - name: INTERRUPT
          value: "true"
      configMap:
        profile: nvidia-h100-inference
        provider: aws
```

### ConfigMap Fields

| Field | Required | Description |
|-------|----------|-------------|
| `profile` | Yes | Workload profile name (e.g., `nvidia-h100-inference`) |
| `provider` | No | Cloud provider name (e.g., `aws`). If specified, provider profile wraps the workload profile |

## Available Profiles

### Workload Profiles (specify in `profile`)

| Profile | Description |
|---------|-------------|
| `nvidia-h100-performance` | General H100 performance optimization |
| `nvidia-h100-inference` | Optimized for inference workloads (CPU isolation, hugepages) |
| `nvidia-h100-multiNodeTraining` | Optimized for distributed training (network buffers, TCP tuning) |

### Cloud Providers (specify in `provider`)

| Provider | Description |
|----------|-------------|
| `aws` | AWS-specific settings (MAC address policy for CNI) |

## Adding OS-Specific Overrides

By default, OS version directories contain symlinks to `os/common/`. To add OS-specific settings:

1. Remove the symlink: `rm skyhook_dir/profiles/os/ubuntu/24.04/nvidia-h100-inference`
2. Create directory: `mkdir skyhook_dir/profiles/os/ubuntu/24.04/nvidia-h100-inference`
3. Add custom `tuned.conf` with OS-specific settings

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

- Multi-distribution support (Ubuntu/Debian, CentOS/RHEL/Amazon Linux)
- Custom profile deployment via configmaps
- Script deployment for complex tuning logic
- Full lifecycle management (install, configure, uninstall)

See the [tuned package README](../tuned/README.md) for complete documentation on all features.

## Version

- **Package Version**: 1.0.0
- **Base Package**: tuned (latest via preprocess.sh)
- **Schema Version**: v1
