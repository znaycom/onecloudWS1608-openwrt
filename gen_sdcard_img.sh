#!/bin/bash

set -e

# ==============================
# 玩客云 OneCloud SD/TF 卡镜像生成脚本
# ==============================

TARGET_DIR="openwrt/bin/targets/amlogic/meson8b"
SDCARD_SCRIPT="./gen_aml_sdcard_img.sh"

# 与 .config 中的分区大小保持一致
BOOTFS_SIZE_MB=32
ROOTFS_SIZE_MB=600

WORK_DIR="sdcard-work"
OUTPUT_NAME="openwrt-amlogic-meson8b-thunder-onecloud-ext4-sdcard.img"
OUTPUT_PATH="${TARGET_DIR}/${OUTPUT_NAME}"

BOOTFS_IMG="${WORK_DIR}/bootfs.img"
ROOTFS_IMG="${WORK_DIR}/rootfs.img"
ROOTFS_MNT="${WORK_DIR}/rootfs-mnt"

echo "========== 检查文件 =========="

if [ ! -d "$TARGET_DIR" ]; then
    echo "错误：找不到目标目录：$TARGET_DIR"
    exit 1
fi

if [ ! -f "$SDCARD_SCRIPT" ]; then
    echo "错误：找不到 SD 卡镜像生成脚本：$SDCARD_SCRIPT"
    exit 1
fi

# 查找构建生成的 eMMC 镜像
EMMC_IMG=$(find "$TARGET_DIR" -maxdepth 1 -type f \
    \( -name "*emmc*.img" -o -name "*ext4-emmc.img" \) \
    | head -n 1)

if [ -z "$EMMC_IMG" ]; then
    echo "错误：没有找到 eMMC img 镜像"
    ls -lh "$TARGET_DIR"
    exit 1
fi

echo "使用镜像：$EMMC_IMG"

# 检查工具
for tool in losetup mount umount dd mkfs.ext4 blockdev ptgen; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "错误：缺少工具：$tool"
        exit 1
    fi
done

echo "========== 准备工作目录 =========="

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$ROOTFS_MNT"

# 清理函数
cleanup() {
    set +e

    if mountpoint -q "$ROOTFS_MNT"; then
        umount "$ROOTFS_MNT"
    fi

    if [ -n "${LOOP_DEV:-}" ]; then
        losetup -d "$LOOP_DEV" 2>/dev/null || true
    fi
}

trap cleanup EXIT

echo "========== 挂载 eMMC 镜像 =========="

# 关联镜像并自动扫描分区
LOOP_DEV=$(losetup --find --show --partscan "$EMMC_IMG")

if [ -z "$LOOP_DEV" ]; then
    echo "错误：无法创建 loop 设备"
    exit 1
fi

echo "Loop 设备：$LOOP_DEV"

# 等待分区设备出现
sleep 2

if [ ! -b "${LOOP_DEV}p1" ]; then
    echo "错误：找不到第 1 分区：${LOOP_DEV}p1"
    ls -l "${LOOP_DEV}"*
    exit 1
fi

if [ ! -b "${LOOP_DEV}p2" ]; then
    echo "错误：找不到第 2 分区：${LOOP_DEV}p2"
    ls -l "${LOOP_DEV}"*
    exit 1
fi

echo "第 1 分区：${LOOP_DEV}p1"
echo "第 2 分区：${LOOP_DEV}p2"

echo "========== 提取 boot 分区 =========="

# 获取 boot 分区大小
BOOT_PART_SIZE=$(blockdev --getsize64 "${LOOP_DEV}p1")

# 提取整个 boot 分区
dd if="${LOOP_DEV}p1" \
   of="$BOOTFS_IMG" \
   bs=4M \
   status=progress \
   conv=fsync

# 将 boot 分区文件截断到实际大小
truncate -s "$BOOT_PART_SIZE" "$BOOTFS_IMG"

echo "bootfs 大小：$(du -h "$BOOTFS_IMG" | awk '{print $1}')"

echo "========== 制作 rootfs 分区 =========="

# 创建 600 MiB 的 ext4 rootfs 镜像
dd if=/dev/zero \
   of="$ROOTFS_IMG" \
   bs=1M \
   count="$ROOTFS_SIZE_MB" \
   status=progress

mkfs.ext4 -F "$ROOTFS_IMG"

mount -o loop "$ROOTFS_IMG" "$ROOTFS_MNT"

# 复制 eMMC 镜像的 rootfs 内容

mkdir -p "$WORK_DIR/emmc-rootfs"
mount "${LOOP_DEV}p2" "$WORK_DIR/emmc-rootfs"

cp -a "$WORK_DIR/emmc-rootfs/." "$ROOTFS_MNT/"

sync

umount "$WORK_DIR/emmc-rootfs"
umount "$ROOTFS_MNT"

echo "rootfs 大小：$(du -h "$ROOTFS_IMG" | awk '{print $1}')"

echo "========== 检查分区镜像大小 =========="

BOOTFS_BYTES=$(stat -c%s "$BOOTFS_IMG")
ROOTFS_BYTES=$(stat -c%s "$ROOTFS_IMG")

MAX_BOOTFS_BYTES=$((BOOTFS_SIZE_MB * 1024 * 1024))
MAX_ROOTFS_BYTES=$((ROOTFS_SIZE_MB * 1024 * 1024))

if [ "$BOOTFS_BYTES" -gt "$MAX_BOOTFS_BYTES" ]; then
    echo "错误：bootfs 镜像超过 ${BOOTFS_SIZE_MB} MiB"
    exit 1
fi

if [ "$ROOTFS_BYTES" -gt "$MAX_ROOTFS_BYTES" ]; then
    echo "错误：rootfs 镜像超过 ${ROOTFS_SIZE_MB} MiB"
    exit 1
fi

echo "bootfs 分区限制：${BOOTFS_SIZE_MB} MiB"
echo "rootfs 分区限制：${ROOTFS_SIZE_MB} MiB"

echo "========== 生成 SD 卡镜像 =========="

rm -f "$OUTPUT_PATH"

chmod +x "$SDCARD_SCRIPT"

"$SDCARD_SCRIPT" \
    "$OUTPUT_PATH" \
    "$BOOTFS_IMG" \
    "$ROOTFS_IMG" \
    "$BOOTFS_SIZE_MB" \
    "$ROOTFS_SIZE_MB"

sync

echo "========== 压缩 SD 卡镜像 =========="

xz -T0 -9 -f "$OUTPUT_PATH"

SHA_FILE="${OUTPUT_PATH}.xz.sha256"
sha256sum "${OUTPUT_PATH}.xz" > "$SHA_FILE"

echo "========== 生成完成 =========="
ls -lh "${OUTPUT_PATH}.xz" "$SHA_FILE"

echo "文件：${OUTPUT_PATH}.xz"
