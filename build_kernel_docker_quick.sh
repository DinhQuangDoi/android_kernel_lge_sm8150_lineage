#!/bin/bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  ./build_kernel_docker_quick.sh --variant mh2lm [--ksu] [--jobs <n>] [--clang-path <path>] [--build <magisk|anykernel>]

Examples:
  ./build_kernel_docker_quick.sh --variant mh2lm
  ./build_kernel_docker_quick.sh --variant mh2lm --ksu
  ./build_kernel_docker_quick.sh --variant mh2lm --clang-path ~/toolchains/weebx-clang15/bin
EOF
}

variant=""
ksu="false"
jobs="24"
clang_path_override=""
build="anykernel"
while [ "$#" -gt 0 ]; do
    case "$1" in
        -v|--variant)
            variant="${2:-}"
            shift 2
            ;;
        -k|--ksu)
            ksu="true"
            shift
            ;;
        -j|--jobs)
            jobs="${2:-}"
            shift 2
            ;;
        --clang-path)
            clang_path_override="${2:-}"
            shift 2
            ;;
        --build)
            build="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [ -z "$variant" ]; then
    echo "Error: --variant is required"
    usage
    exit 1
fi

if [ "$build" != "magisk" ] && [ "$build" != "anykernel" ]; then
    echo "Error: --build must be either 'magisk' or 'anykernel'"
    usage
    exit 1
fi

case "$variant" in
    mh2lm)
        image_name="Image-mh2lm"
        history_dir="./release/Dragon/history-mh2lm"
        defconfig="vendor/lineageos_mh2_defconfig"
        ;;
    *)
        echo "Error: invalid variant '$variant'"
        usage
        exit 1
        ;;
esac

if [ -n "$clang_path_override" ]; then
    CLANG_PATH="$clang_path_override"
else
    CLANG_PATH=~/toolchains/neutron-clang/bin
fi

echo
echo "Issue Build Commands"
echo
echo "Variant   : $variant"
echo "KSU       : $ksu"
echo "Defconfig : $defconfig"
echo "Clang path: $CLANG_PATH"
echo "Jobs      : $jobs"
echo "Build     : $build"

mkdir -p out
echo 0 > ./out/.version

export ARCH=arm64
export SUBARCH=arm64
export PATH="${CLANG_PATH}:${PATH}"
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
export CLANG_TRIPLE=aarch64-linux-gnu-

ccache_prefix=""
if command -v ccache &>/dev/null; then
    ccache_prefix="ccache "
fi

make_args=(
    CC="${ccache_prefix}clang"
    AR=llvm-ar
    NM=llvm-nm
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    STRIP=llvm-strip
    O=out
    KCFLAGS="-Wno-implicit-enum-enum-cast -Wno-default-const-init-var-unsafe -Wno-default-const-init-field-unsafe"
)

echo
echo "Set DEFCONFIG"
echo
make "${make_args[@]}" "$defconfig"

echo
echo "Force correct KSU hook in .config"
echo
if [ "$ksu" = "true" ]; then
    scripts/config --file out/.config \
        --enable CONFIG_KSU_SUSFS \
        --disable CONFIG_KSU_TRACEPOINT_HOOK \
        --disable CONFIG_KSU_MANUAL_HOOK
else
    scripts/config --file out/.config \
        --disable CONFIG_KSU \
        --disable CONFIG_KSU_TRACEPOINT_HOOK \
        --disable CONFIG_KSU_MANUAL_HOOK \
        --disable CONFIG_KSU_SUSFS
fi
make "${make_args[@]}" olddefconfig

echo
echo "Build The Good Stuff"
echo
make "${make_args[@]}" -j"$jobs"

release_dir="./release/Dragon"
if [ "$build" = "magisk" ]; then
    release_file="$release_dir/$image_name.gz-dtb"
else
    release_file="$release_dir/$image_name"
fi
mkdir -p "$release_dir" "$history_dir"

if [ -f "$release_file" ]; then
    n=$(ls "$history_dir" 2>/dev/null | sed -n "s/^${image_name}\([0-9][0-9]*\)$/\1/p" | sort -nr | head -n1)
    n=$(( ${n:-0} + 1 ))
    if [ "$build" = "magisk" ]; then
        cp -f "$release_file" "$history_dir/${image_name}${n}.gz-dtb"
    else
        cp -f "$release_file" "$history_dir/${image_name}${n}"
    fi
fi

if [ "$build" = "magisk" ]; then
    cp -f ./out/arch/arm64/boot/Image.gz-dtb "$release_file"
else
    cp -f ./out/arch/arm64/boot/Image "$release_file"
fi

if [ "$variant" = "flash" ]; then
    ./out/scripts/sign-file sha512 \
        out/certs/signing_key.pem \
        out/certs/signing_key.x509 \
        out/drivers/input/touchscreen/lge/module/touch_module_s3706.ko \
        ./release/Dragon/touch_module_s3706.ko
fi
