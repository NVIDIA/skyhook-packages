# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Extends the tuning package with baked-in H100/GB200 configs for GKE.
# Config step: prepare_nvidia_configs.sh (populate configmaps from profile)
#              then update_settings.sh (base tuning apply).

ARG TUNING_VERSION=1.1.4
FROM ghcr.io/nvidia/skyhook-packages/tuning:${TUNING_VERSION}

COPY profiles/ /skyhook-package/profiles/
COPY skyhook_dir/prepare_nvidia_configs.sh /skyhook-package/skyhook_dir/
COPY skyhook_dir/prepare_nvidia_configs_check.sh /skyhook-package/skyhook_dir/
COPY config.json /skyhook-package/

RUN chmod +x /skyhook-package/skyhook_dir/prepare_nvidia_configs.sh \
             /skyhook-package/skyhook_dir/prepare_nvidia_configs_check.sh \
             /skyhook-package/skyhook_dir/*.sh
