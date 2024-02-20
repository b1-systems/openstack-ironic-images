#!/bin/bash

set -eoux

# BUILDROOT="$PWD/mkosi.workspace/$RANDOM/root"
# OUTPUTDIR="$PWD/mkosi.output/ubuntu~jammy"
# IMAGE_ID="ubuntu-22.04-amd64"
# IMAGE_VERSION="2023.05.23"

# call the trap whenever something fails due to -e or on normal shell exit
trap cleanup ERR EXIT

function wait_for_existence() {
    local _file="$1"
    local -i _now="$SECONDS"
    while test ! -e "$_file"; do
        if ((_now + 10 < SECONDS)); then
            printf '%s not exists after 10 seconds!\n' "$_file"
            return 1
        fi
        sleep 0.2
    done
    return 0
}

function is_mountpoint() {
    # compare the device node numbers of a dir and its parent.
    # if they differ, than it's an mountpoint
    local _dir="$1"
    if ! test -e "$_dir"; then
        return 1
    fi
    declare -i dev_number parent_dev_number
    dev_number="$(stat -c '%d' "$_dir")"
    parent_dev_number="$(stat -c '%d' "${_dir}/..")"
    return $((dev_number == parent_dev_number))
}

function cleanup() {
    declare -i call_signal="$?"
    printf "Cleaning up\n"
    sync
    if is_mountpoint "$ROOT_MNT_DIR"; then
        umount -R "$ROOT_MNT_DIR"
    fi
    if vgs -q "$VG_NAME" &>/dev/null; then
        lvchange --activate n "$VG_NAME"
        vgchange --activate n "$VG_NAME"
    fi
    cryptsetup close "$LUKSLABEL" || true
    if [[ "$(losetup -n -O 'BACK-FILE' -l "$LOOP_DEVICE")" != "" ]]; then
        losetup -d "$LOOP_DEVICE"
    fi
    rm -rf "$ROOT_MNT_DIR"
    if ((call_signal > 0)); then
        exit "$call_signal"
    fi
}

declare -r OUTPUTDIR="$PWD/mkosi.output"
declare -r BUILDROOT="$OUTPUTDIR/${IMAGE_ID}_${IMAGE_VERSION}"
declare -r RAW_FILE="${BUILDROOT}.raw"
declare -r RAW_ZST_FILE="${RAW_FILE}.zst"
declare -r QCOW2_FILE="${RAW_FILE/.raw/.qcow2}"
declare -r VG_NAME='system'
declare -r LVM_DEFINITION_FILE="lvm-${VG_NAME}.csv"
declare -r ROOT_MNT_DIR="${BUILDROOT}.mount"
declare -x -r MKE2FS_CONFIG="${BUILDROOT}/etc/mke2fs.conf"
declare -r LUKSKEYFILE="${BUILDROOT}/boot/efi/loader/random-seed"
declare -r LUKSLABEL="LUKS_LVM"

rm -rf "$QCOW2_FILE" "$RAW_FILE" "$ROOT_MNT_DIR"
mkdir -p "$ROOT_MNT_DIR"
printf 'Created temp root mnt dir %s\n' "$ROOT_MNT_DIR"
dd "if=/dev/zero" "of=$RAW_FILE" bs=1 count=0 seek=100G
printf 'Created raw file %s\n' "$RAW_FILE"

sgdisk -n '1:0:+200M' -c '1:OSISM_HV_EFI_PARTITION' -t '1:c12a7328-f81f-11d2-ba4b-00a0c93ec93b' \
    -n '2:0:+1G' -c '2:OSISM_HV_BOOT_PARTITION' -t '2:bc13c2ff-59e6-4262-a352-b275fd6f7172' \
    -N '3' -c '3:OSISM_HV_LVM_PARTITION' -t '3:8e00' \
    "$RAW_FILE"

LOOP_DEVICE="$(losetup -P -f --show "$RAW_FILE")"

partlabel='/dev/disk/by-partlabel/OSISM_HV_EFI_PARTITION'
wait_for_existence "$partlabel"
mkfs.vfat -F 32 -n esp "$partlabel"
partlabel='/dev/disk/by-partlabel/OSISM_HV_BOOT_PARTITION'
wait_for_existence "$partlabel"
mkfs.ext4 -FF -L boot -U bc13c2ff-59e6-4262-a352-b275fd6f7172 "$partlabel"
partlabel='/dev/disk/by-partlabel/OSISM_HV_LVM_PARTITION'
wait_for_existence "$partlabel"
cryptsetup --batch-mode --key-file "$LUKSKEYFILE" luksFormat "$partlabel"
cryptsetup --batch-mode --key-file "$LUKSKEYFILE" open "$partlabel" "$LUKSLABEL"
partlabel="/dev/mapper/$LUKSLABEL"
wait_for_existence "$partlabel"
pvcreate -ff "$partlabel"
vgcreate "$VG_NAME" "$partlabel"

while read -r lv_name lv_size fs_type fs_label fs_uuid; do
    if [[ "$lv_name" == '#' ]] || [[ "$lv_name" == "" ]]; then
        continue
    fi
    device_path="/dev/mapper/${VG_NAME//-/--}-${lv_name//-/--}"
    lvcreate -L "$lv_size" -n "$lv_name" "$VG_NAME"
    printf 'Creating %s at %s\n' "$fs_type" "$device_path"
    if [[ "$fs_type" == "swap" ]]; then
        mkswap -L "$fs_label" -U "$fs_uuid" "$device_path"
    else
        "mkfs.${fs_type}" -FF -L "$fs_label" -U "$fs_uuid" "$device_path"

        if [[ "$fs_label" == 'root' ]]; then
            mount_point="$ROOT_MNT_DIR"
        else
            mount_point="$ROOT_MNT_DIR/${fs_label//-//}"
        fi
        printf 'Mounting %s\n' "$mount_point"
        mkdir -p "$mount_point"
        mount -orw "LABEL=$fs_label" "${mount_point}"
    fi
done <"$LVM_DEFINITION_FILE"
mount_point="$ROOT_MNT_DIR/boot"
printf 'Mounting %s\n' "$mount_point"
mkdir -p "$mount_point"
mount -orw "LABEL=boot" "$mount_point"
mkdir -p "$mount_point/efi"
mount_point="$ROOT_MNT_DIR/boot/efi"
printf 'Mounting %s\n' "$mount_point"
mkdir -p "$mount_point"
mount -orw "LABEL=esp" "$mount_point"

printf 'Moving files from %s to %s\n' "$BUILDROOT" "$ROOT_MNT_DIR"
# boot/vmlinuz{,.old} are symlinks, but the target is a vfat partition without support
rsync -aAXUHS --exclude '/proc/**' --exclude '/sys/**' --exclude '/dev/**' --exclude '/tmp/**' --exclude '/run/**' "${BUILDROOT}/" "$ROOT_MNT_DIR"
sync

cleanup

printf 'Converting %s to %s...\n' "$RAW_FILE" "$QCOW2_FILE"
qemu-img convert -c -O qcow2 "$RAW_FILE" "$QCOW2_FILE"
zstd --force --ultra -T0 "$RAW_FILE"
chown "$SUDO_UID:$SUDO_GID" "$RAW_FILE" "$RAW_ZST_FILE" "$QCOW2_FILE"
