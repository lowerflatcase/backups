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

    CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo)
    if [[ "$CPU_VENDOR" == *Intel* ]]; then MICROCODE="intel-ucode"; else MICROCODE="amd-ucode"; fi

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

    pacstrap -K /mnt base linux-lts linux-firmware networkmanager sudo nano "$MICROCODE"
    
    genfstab -U /mnt > /mnt/etc/fstab

    arch-chroot /mnt env ARCH_CHROOT=1 bash -c "curl -fsSL https://raw.githubusercontent.com/lowerflatcase/backups/main/arch-hyprland.sh | bash"

else

    echo -n "Hostname: " >/dev/tty
    read HOSTNAME </dev/tty
    echo "$HOSTNAME" > /etc/hostname

    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    hwclock --systohc
    
    sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

    passwd </dev/tty

    echo -n "Username: " >/dev/tty
    read USERNAME </dev/tty
    
    id "$USERNAME" &>/dev/null || useradd -m -G wheel -s /bin/bash "$USERNAME"
    passwd "$USERNAME" </dev/tty

    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-wheel
    systemctl enable NetworkManager

    bootctl install

    cat > /boot/loader/loader.conf <<EOF
default arch
timeout 5
editor no
EOF

    ROOT_DEV=$(findmnt -no SOURCE /)
    ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$ROOT_DEV")

    if [[ -f /boot/intel-ucode.img ]]; then
        UCODE_INITRD="initrd  /intel-ucode.img"
    elif [[ -f /boot/amd-ucode.img ]]; then
        UCODE_INITRD="initrd  /amd-ucode.img"
    else
        UCODE_INITRD=""
    fi

    cat > /boot/loader/entries/arch.conf <<EOF
title Arch
linux /vmlinuz-linux-lts
$UCODE_INITRD
initrd /initramfs-linux-lts.img
options root=PARTUUID=$ROOT_PARTUUID rw
EOF

    pacman -S --noconfirm hyprland alacritty mesa vulkan-intel git base-devel

    sudo -u "$USERNAME" bash -c "
        cd /home/$USERNAME
        rm -rf yay
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        yay -S --noconfirm brave-bin
        cd ..
        rm -rf yay
        mkdir -p /home/$USERNAME/.config/hypr
        curl -fsSL https://raw.githubusercontent.com/lowerflatcase/backups/main/resources/hyprland.lua -o /home/$USERNAME/.config/hypr/hyprland.lua
        grep -q \"start-hyprland\" /home/$USERNAME/.bashrc || {
            echo 'if [[ -z \"\$WAYLAND_DISPLAY\" ]]; then' >> /home/$USERNAME/.bashrc
            echo '    read -p \"Press Enter to start Hyprland or type anything to cancel: \" choice' >> /home/$USERNAME/.bashrc
            echo '    if [[ -z \"\$choice\" ]]; then exec start-hyprland; fi' >> /home/$USERNAME/.bashrc
            echo 'fi' >> /home/$USERNAME/.bashrc
        }
    "

    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel

fi