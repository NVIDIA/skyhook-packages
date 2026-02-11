# NVIDIA Tuned Package

A Skyhook package that extends the base `tuned` package with NVIDIA-specific performance profiles for GPU and DGX systems.

## Overview

This package inherits from the base `tuned` package and adds pre-configured tuned profiles optimized for NVIDIA hardware. The profiles are organized by:

- **Common base profiles**: Foundational settings deployed to `/usr/lib/tuned/`
- **OS-specific workload profiles**: Profiles that may vary by OS version
- **Service profiles**: Service-specific settings (AWS, GCP, etc.)

The configmap uses an **intent-based** model where you specify **what** you want (intent + accelerator) rather than a specific profile name. The profile name `nvidia-{accelerator}-{intent}` is constructed automatically.

## Directory Structure

```
profiles/
├── common/                  # Base profiles → /usr/lib/tuned/
│   ├── nvidia-base/
│   └── nvidia-acs-disable/
├── os/
│   ├── common/              # Default workload profiles
│   │   ├── nvidia-h100-performance/
│   │   ├── nvidia-h100-inference/
│   │   └── nvidia-h100-multiNodeTraining/
│   ├── ubuntu/
│   │   ├── 22.04/          # Symlinks to os/common/ (override when needed)
│   │   └── 24.04/
│   └── rhel/
│       └── 9/
└── service/
    └── aws/
        ├── tuned.conf.template  # Service template (include= added dynamically)
        └── script.sh
```

Note: Profiles are stored in `profiles/` (not `root_dir/`) to avoid polluting the host filesystem during package extraction. The prepare scripts explicitly copy profiles to the appropriate tuned directories.

## How It Works

1. **Prepare stage**: `prepare_nvidia_profiles.sh` runs:
   - Reads `intent` and `accelerator` from the configmap
   - Constructs the profile name as `nvidia-{accelerator}-{intent}`
   - Deploys common base profiles to `/usr/lib/tuned/`
   - Detects OS from `/etc/os-release`
   - Copies the appropriate OS-specific workload profiles to `/etc/tuned/`
   - If a `service` is specified, creates service profile with dynamic `include=` pointing to the workload profile

2. **Config stage**: The inherited `tuned` package applies the configured profile

### Profile Name Construction

The profile name is built from the configmap fields:

```
nvidia-{accelerator}-{intent}
```

Examples:
| `accelerator` | `intent` | Constructed Profile |
|---------------|----------|---------------------|
| `h100` | `performance` | `nvidia-h100-performance` |
| `h100` | `inference` | `nvidia-h100-inference` |
| `h100` | `multiNodeTraining` | `nvidia-h100-multiNodeTraining` |

### Inheritance Chain

When you specify `intent: inference`, `accelerator: h100`, and `service: aws`:

```
aws (active profile)
  └── includes: nvidia-h100-inference
        └── includes: nvidia-h100-performance
              └── includes: nvidia-acs-disable
                    └── includes: nvidia-base
```

## Usage

### Basic Usage (No Service)

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
        intent: performance
        accelerator: h100
```

### With Service (e.g., AWS)

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
        intent:
          type: reboot
      env:
        - name: INTERRUPT
          value: "true"
      configMap:
        intent: inference
        accelerator: h100
        service: aws
```

### ConfigMap Fields

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `accelerator` | Yes | — | GPU/accelerator type (e.g., `h100`) |
| `intent` | No | `performance` | Workload intent (e.g., `inference`, `performance`, `multiNodeTraining`) |
| `service` | No | — | Service name (e.g., `aws`). If specified, service profile wraps the workload profile |

## Available Profiles

### Intents (specify in `intent`)

| Intent | Description |
|--------|-------------|
| `performance` | General GPU performance optimization |
| `inference` | Optimized for inference workloads (CPU isolation, hugepages) |
| `multiNodeTraining` | Optimized for distributed training (network buffers, TCP tuning) |

### Accelerators (specify in `accelerator`)

| Accelerator | Description |
|-------------|-------------|
| `h100` | NVIDIA H100 GPU |

### Services (specify in `service`)

| Service | Description |
|---------|-------------|
| `aws` | AWS-specific settings (MAC address policy for CNI) |

## Adding OS-Specific Overrides

By default, OS version directories contain symlinks to `os/common/`. To add OS-specific settings:

1. Remove the symlink: `rm profiles/os/ubuntu/24.04/nvidia-h100-inference`
2. Create directory: `mkdir profiles/os/ubuntu/24.04/nvidia-h100-inference`
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
