# NVIDIA Setup Package

A Skyhook package that applies the same node setup steps as the dgxcloud_aws_eks VMI framework for selected (service, accelerator) combinations. It runs **after** the machine is up (Skyhook on a live node) and performs upgrade, EFA driver install, Lustre client install, chrony configuration, and local disk setup.

## Overview

- **Opinionated:** Each (service, accelerator) has very specific baked-in configuration (exact kernel, lustre, EFA versions) in `defaults/*.conf`.
- **Override via environment variables:** You can override kernel, EFA, lustre (and ofi if added) with `EIDOS_KERNEL`, `EIDOS_EFA`, `EIDOS_LUSTRE`, `EIDOS_OFI` in the Skyhook package `env`.
- **Configmap:** Only `service` and `accelerator` are required. Unsupported combinations fail with a clear error.

## Assumptions:

- OS: `ubuntu`

## Supported Combinations

| service | accelerator | default kernel      | default lustre | default efa |
|---------|-------------|---------------------|----------------|-------------|
| eks     | h100        | 5.15.0-1025-aws     | aws            | 1.31.0      |
| eks     | gb200       | 6.8.0-1012-aws      | aws            | 1.31.0      |

Defaults are defined in `skyhook_dir/defaults/eks-h100.conf` and `eks-gb200.conf`. Keep this table in sync when adding or changing defaults.

## Configuration

**ConfigMap (required):**

- `service` – e.g. `eks`
- `accelerator` – e.g. `h100`, `gb200`

**Environment variables (optional overrides):**

Set these on the package spec in the Skyhook Custom Resource (`spec.packages.<name>.env`):

- `EIDOS_KERNEL` – kernel version (overrides default from defaults file)
- `EIDOS_EFA` – EFA installer version
- `EIDOS_LUSTRE` – lustre version or `aws` for AWS FSx repo
- `EIDOS_OFI` – reserved for future OFI version override

## Apply Steps (EKS)

For `service=eks` the apply step runs, in order:

1. **upgrade** – `apt-get update && apt-get upgrade -y`
2. **install-efa-driver** – download and run AWS EFA installer
3. **install-lustre** – install Lustre client (AWS repo or build from source)
4. **configure-chrony** – install chrony and point to IMDS `169.254.169.123`
5. **setup-local-disks** – install `setup-local-disks.sh` to `/usr/local/bin` and run it (e.g. `raid0`). A **reboot may be required** after apply so the disk layout is active (use Skyhook interrupt or reboot the node separately).

OFI, hardening, and system-node-settings are **not** included.

## Apply-Check

Apply-check validates that all steps for the selected (service, accelerator) are complete: upgrade (apt update ok), EFA present, Lustre client modules installed, chrony configured with IMDS, and `/usr/local/bin/setup-local-disks` present and executable.

## Usage Example

```yaml
apiVersion: skyhook.nvidia.com/v1alpha1
kind: Skyhook
metadata:
  name: nvidia-setup-eks
spec:
  nodeSelectors:
    matchLabels:
      nvidia.com/gpu: "true"
  packages:
    nvidia-setup:
      image: ghcr.io/nvidia/skyhook-packages/nvidia-setup
      version: 0.1.0
      configMap:
        service: eks
        accelerator: h100
      # Optional overrides:
      env:
        - name: EIDOS_EFA
          value: "1.31.0"
```

## Adding a New (service, accelerator)

1. Add `skyhook_dir/defaults/<service>-<accelerator>.conf` with `kernel=`, `lustre=`, `efa=`.
2. In `apply.sh`, add a `run_<service>_<accelerator>()` function that runs the step scripts for that combination, and add a case branch: `<service>-<accelerator>) run_<service>_<accelerator> ;;`.
3. In `apply_check.sh`, add `check_<service>_<accelerator>()` and the same case branch.
4. Rebuild the image and update this README’s supported combinations table.
