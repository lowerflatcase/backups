#!/usr/bin/env python3

import os
import sys
import subprocess
import time

def run(cmd, check=True, capture=False):
    if capture:
        return subprocess.run(cmd, shell=True, check=check, capture_output=True, text=True).stdout.strip()
    return subprocess.run(cmd, shell=True, check=check)

def host_phase():
    run("setfont ter-132b", check=False)

    try:
        with open("/sys/firmware/efi/fw_platform_size", "r") as f:
            if f.read().strip() != "64":
                sys.exit("Error: Not 64-bit UEFI.")
    except FileNotFoundError:
        sys.exit("Error: UEFI not found.")

    run("timedatectl set-ntp true")
    while True:
        if "yes" in run("timedatectl show --property=NTPSynchronized --value", capture=True):
            break
        time.sleep(1)

    run("lsblk -dpno NAME,SIZE | grep -Ev 'loop|rom'")
    disk = input("Disk: ").strip()
    if not disk:
        sys.exit("Error: No disk selected.")

    run("umount -R /mnt", check=False)
    run("swapoff -a", check=False)

    run(f"wipefs -af {disk}")
    run(f"sgdisk --zap-all {disk}")
    run(f"parted -s {disk} mklabel gpt")
    run(f"parted -s {disk} mkpart ESP fat32 1MiB 1025MiB")
    run(f"parted -s {disk} set 1 esp on")
    run(f"parted -s {disk} mkpart ROOT ext4 1025MiB 100%")

    if "nvme" in disk:
        efi_part = f"{disk}p1"
        root_part = f"{disk}p2"
    else:
        efi_part = f"{disk}1"
        root_part = f"{disk}2"

    run(f"mkfs.fat -F32 {efi_part}")
    run(f"mkfs.ext4 -F {root_part}")

    run(f"mount {root_part} /mnt")
    os.makedirs("/mnt/boot", exist_ok=True)
    run(f"mount {efi_part} /mnt/boot")

    run("pacstrap -K /mnt base linux-lts linux-firmware networkmanager sudo nano intel-ucode python")
    run("genfstab -U /mnt > /mnt/etc/fstab")

    script_path = os.path.abspath(__file__)
    run(f"cp {script_path} /mnt/install_chroot.py")
    run("arch-chroot /mnt env ARCH_CHROOT=1 python /install_chroot.py")

def chroot_phase():
    hostname = input("Hostname: ").strip()
    with open("/etc/hostname", "w") as f:
        f.write(hostname + "\n")

    run("ln -sf /usr/share/zoneinfo/UTC /etc/localtime")
    run("hwclock --systohc")

    run("sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen")
    run("locale-gen")
    with open("/etc/locale.conf", "w") as f:
        f.write("LANG=en_US.UTF-8\n")

    run("passwd")

    username = input("Username: ").strip()
    if run(f"id {username}", check=False).returncode != 0:
        run(f"useradd -m -G wheel -s /bin/bash {username}")

    run(f"passwd {username}")

    with open("/etc/sudoers.d/10-wheel", "w") as f:
        f.write("%wheel ALL=(ALL:ALL) NOPASSWD: ALL\n")

    run("systemctl enable NetworkManager")
    run("bootctl install")

    with open("/boot/loader/loader.conf", "w") as f:
        f.write("default arch\ntimeout 5\neditor no\n")

    root_dev = run("findmnt -no SOURCE /", capture=True)
    root_partuuid = run(f"blkid -s PARTUUID -o value {root_dev}", capture=True)

    arch_conf = f"""title Arch
linux /vmlinuz-linux-lts
initrd /intel-ucode.img
initrd /initramfs-linux-lts.img
options root=PARTUUID={root_partuuid} rw
"""
    os.makedirs("/boot/loader/entries", exist_ok=True)
    with open("/boot/loader/entries/arch.conf", "w") as f:
        f.write(arch_conf)

    run("pacman -S --noconfirm hyprland alacritty mesa vulkan-intel git base-devel intel-media-driver libva-utils")

    user_script = f"""
cd /home/{username}
rm -rf yay
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
yay -S --noconfirm brave-bin
cd ..
rm -rf yay
mkdir -p /home/{username}/.config/hypr
curl -fsSL https://raw.githubusercontent.com/lowerflatcase/backups/main/resources/hyprland.lua -o /home/{username}/.config/hypr/hyprland.lua
if ! grep -q "start-hyprland" /home/{username}/.bashrc; then
    echo 'if [[ -z "$WAYLAND_DISPLAY" ]]; then' >> /home/{username}/.bashrc
    echo '    read -p "Press Enter to start Hyprland or type anything to cancel: " choice' >> /home/{username}/.bashrc
    echo '    if [[ -z "$choice" ]]; then exec start-hyprland; fi' >> /home/{username}/.bashrc
    echo 'fi' >> /home/{username}/.bashrc
fi
"""
    with open("/tmp/user_setup.sh", "w") as f:
        f.write(user_script)

    run(f"sudo -u {username} bash /tmp/user_setup.sh")
    os.remove("/tmp/user_setup.sh")

    with open("/etc/sudoers.d/10-wheel", "w") as f:
        f.write("%wheel ALL=(ALL:ALL) ALL\n")

if __name__ == "__main__":
    if os.environ.get("ARCH_CHROOT") == "1":
        chroot_phase()
    else:
        host_phase()
