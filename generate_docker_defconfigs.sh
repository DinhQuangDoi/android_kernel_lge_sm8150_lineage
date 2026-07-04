#!/bin/bash
# Generate docker defconfigs for LineageOS kernel builds
# Based on the lineageos_*_defconfig files with docker-specific additions

set -euo pipefail

BASE_DIR="arch/arm64/configs/vendor"

docker_extras() {
    cat <<'EOF'
CONFIG_POSIX_MQUEUE=y
CONFIG_CGROUP_PIDS=y
CONFIG_CGROUP_DEVICE=y
CONFIG_USER_NS=y
CONFIG_PID_NS=y
CONFIG_IPC_NS=y
CONFIG_SCHED_TUNE=y
CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y
CONFIG_NETFILTER_XT_MATCH_IPVS=y
CONFIG_IP6_NF_TARGET_MASQUERADE=y
CONFIG_IP6_NF_NAT=y
CONFIG_BTRFS_FS=y
CONFIG_BTRFS_FS_POSIX_ACL=y
EOF
}

ksu_extras() {
    cat <<'EOF'
CONFIG_KSU=y
CONFIG_KSU_SUSFS_SUS_MEMFD=y
EOF
}

variants=("alpha" "beta" "flash" "mh2")

for variant in "${variants[@]}"; do
    base="${BASE_DIR}/lineageos_${variant}_defconfig"

    # Non-KSU docker
    docker="${BASE_DIR}/lineageos_${variant}_docker_defconfig"
    if [ ! -f "$docker" ]; then
        cp "$base" "$docker"
        docker_extras >> "$docker"
        echo "Created: $docker"
    else
        echo "Exists: $docker"
    fi

    # KSU docker
    ksu_docker="${BASE_DIR}/lineageos_${variant}_ksu_docker_defconfig"
    if [ ! -f "$ksu_docker" ]; then
        cp "$base" "$ksu_docker"
        docker_extras >> "$ksu_docker"
        ksu_extras >> "$ksu_docker"
        echo "Created: $ksu_docker"
    else
        echo "Exists: $ksu_docker"
    fi
done
