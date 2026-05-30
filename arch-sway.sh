#!/bin/bash

set -euo pipefail

if [[ "${ARCH_CHROOT:-0}" == "1" ]]; then
    INSIDE_CHROOT=true
else
    INSIDE_CHROOT=false
fi

if [[ "$INSIDE_CHROOT" == false ]]; then

    setfont ter-132b
    [[ "$(cat /sys/firmware/efi/fw_platform_size 2>/dev/null)" == "64" ]] || exit 1

    timedatectl set-ntp true
    until timedatectl show --property=NTPSynchronized --value | grep -q yes; do sleep 1; done

    lsblk -dpno NAME,SIZE | grep -Ev "loop|rom" >/dev/tty
    echo -n "Disk: " >/dev/tty
    read DISK </dev/tty

    echo -n "Hostname: " >/dev/tty
    read HOSTNAME </dev/tty
    
    echo -n "Username: " >/dev/tty
    read USERNAME </dev/tty
    
    echo -n "Root Password: " >/dev/tty
    read ROOT_PASS </dev/tty
    
    echo -n "User Password: " >/dev/tty
    read USER_PASS </dev/tty

    echo "WARNING: Disk $DISK will be wiped. Press ENTER to continue or CTRL+C to cancel." >/dev/tty
    read </dev/tty

    umount -R /mnt 2>/dev/null || true
    swapoff -a 2>/dev/null || true

    wipefs -af "$DISK"
    sgdisk --zap-all "$DISK"
    parted -s "$DISK" mklabel gpt
    parted -s "$DISK" mkpart ESP fat32 1MiB 1025MiB
    parted -s "$DISK" set 1 esp on
    parted -s "$DISK" mkpart ROOT ext4 1025MiB 100%

    if [[ "$DISK" == *"nvme"* ]]; then
        EFI_PART="${DISK}p1"
        ROOT_PART="${DISK}p2"
    else
        EFI_PART="${DISK}1"
        ROOT_PART="${DISK}2"
    fi

    mkfs.fat -F32 "$EFI_PART"
    mkfs.ext4 -F "$ROOT_PART"

    mount "$ROOT_PART" /mnt
    mkdir -p /mnt/boot
    mount "$EFI_PART" /mnt/boot

    pacstrap -K /mnt base linux linux-firmware networkmanager sudo nano intel-ucode </dev/tty
    
    genfstab -U /mnt > /mnt/etc/fstab

    cat > /mnt/root/install_vars <<EOF
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
ROOT_PASS="$ROOT_PASS"
USER_PASS="$USER_PASS"
EOF

    arch-chroot /mnt env ARCH_CHROOT=1 bash -c "curl -fsSL https://lowerflatcase.me/backups/arch-sway.sh | bash"

else

    source /root/install_vars
    rm -f /root/install_vars

    echo "$HOSTNAME" > /etc/hostname

    ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
    hwclock --systohc
    
    sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

    echo "root:$ROOT_PASS" | chpasswd

    id "$USERNAME" &>/dev/null || useradd -m -G wheel -s /bin/bash "$USERNAME"
    echo "$USERNAME:$USER_PASS" | chpasswd

    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-wheel
    systemctl enable NetworkManager

    bootctl install || bootctl update

    cat > /boot/loader/loader.conf <<EOF
default arch
timeout 5
editor no
EOF

    ROOT_DEV=$(findmnt -no SOURCE /)
    ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$ROOT_DEV")

    cat > /boot/loader/entries/arch.conf <<EOF
title Arch
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=PARTUUID=$ROOT_PARTUUID rw
EOF

    pacman -S --needed sway foot mesa vulkan-intel intel-media-driver git base-devel </dev/tty

    sudo -u "$USERNAME" bash -c "
        cd /home/$USERNAME
        curl -fsS https://dl.brave.com/install.sh | FLAVOR=origin CHANNEL=nightly sh </dev/tty
        grep -q \"alias sway\" /home/$USERNAME/.bashrc || {
            echo \"alias sway='exec sway'\" >> /home/$USERNAME/.bashrc
        }
    "

    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel

fi
