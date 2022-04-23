#!/bin/sh -eux

case "$PACKER_BUILDER_TYPE" in
  qemu) exit 0 ;;
esac

# Whiteout root
count=$(df --sync -kP / | tail -n1  | awk -F ' ' '{print $4}')
count=$(($count-1))
dd if=/dev/zero of=/whitespace bs=1M count=$count || echo "dd exit code $? is suppressed";
rm /whitespace

# Whiteout /boot/efi
count=$(df --sync -kP /boot/efi | tail -n1 | awk -F ' ' '{print $4}')
count=$(($count-1))
dd if=/dev/zero of=/boot/efi/whitespace bs=1M count=$count || echo "dd exit code $? is suppressed";
rm /boot/efi/whitespace

# Whiteout /home
count=$(df --sync -kP /home | tail -n1 | awk -F ' ' '{print $4}')
count=$(($count-1))
dd if=/dev/zero of=/home/whitespace bs=1M count=$count || echo "dd exit code $? is suppressed";
rm /home/whitespace

# Whiteout /var
count=$(df --sync -kP /var | tail -n1 | awk -F ' ' '{print $4}')
count=$(($count-1))
dd if=/dev/zero of=/var/whitespace bs=1M count=$count || echo "dd exit code $? is suppressed";
rm /var/whitespace

# Whiteout /tmp
count=$(df --sync -kP /tmp | tail -n1 | awk -F ' ' '{print $4}')
count=$(($count-1))
dd if=/dev/zero of=/tmp/whitespace bs=1M count=$count || echo "dd exit code $? is suppressed";
rm /tmp/whitespace

# Whiteout /var/log/audit
count=$(df --sync -kP /var/log/audit | tail -n1 | awk -F ' ' '{print $4}')
count=$(($count-1))
dd if=/dev/zero of=/var/log/audit/whitespace bs=1M count=$count || echo "dd exit code $? is suppressed";
rm /var/log/audit/whitespace

# Whiteout /var/lib/docker
count=$(df --sync -kP /var/lib/docker | tail -n1 | awk -F ' ' '{print $4}')
count=$(($count-1))
dd if=/dev/zero of=/var/lib/docker/whitespace bs=1M count=$count || echo "dd exit code $? is suppressed";
rm /var/lib/docker/whitespace

set +e
swapuuid="`/sbin/blkid -o value -l -s UUID -t TYPE=swap`";
case "$?" in
    2|0) ;;
    *) exit 1 ;;
esac
set -e

if [ "x${swapuuid}" != "x" ]; then
    # Whiteout the swap partition to reduce box size
    # Swap is disabled till reboot
    swappart="`readlink -f /dev/disk/by-uuid/$swapuuid`";
    /sbin/swapoff "$swappart" || true;
    dd if=/dev/zero of="$swappart" bs=1M || echo "dd exit code $? is suppressed";
    /sbin/mkswap -U "$swapuuid" "$swappart";
fi

sync;
