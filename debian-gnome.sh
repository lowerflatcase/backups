#!/usr/bin/env bash

set -eo pipefail

sudo -v

read -rp "Enter Git name: " GIT_NAME
read -rp "Enter Git email: " GIT_EMAIL
read -rp "Enter server IP: " SERVER_IP
read -rp "Enter SSH username [admin]: " SSH_USER

SSH_USER="${SSH_USER:-admin}"

REPO_DIR="$HOME/backups"
RESOURCES="$REPO_DIR/resources"

clone_repository() {
    if [ -d "$REPO_DIR/.git" ]; then
        git -C "$REPO_DIR" pull
    else
        git clone https://github.com/lowerflatcase/backups.git "$REPO_DIR"
    fi
}

remove_bloat_packages() {
    sudo apt-get purge -y gnome-calculator baobab evolution firefox-esr gnome-calendar gnome-characters gnome-clocks gnome-connections gnome-contacts gnome-disk-utility gnome-logs gnome-maps gnome-music gnome-sound-recorder gnome-system-monitor gnome-tour gnome-weather 'libreoffice*' malcontent seahorse shotwell simple-scan totem yelp gnome-snapshot gnome-font-viewer gnome-text-editor || true
}

setup_ssh_hosts() {
    mkdir -p ~/.ssh
    touch ~/.ssh/config
    chmod 600 ~/.ssh/config

    sed -i '/^Host gfnq$/,/^[[:space:]]*$/d' ~/.ssh/config

    cat >> ~/.ssh/config <<EOF
Host gfnq
    HostName $SERVER_IP
    User $SSH_USER
    IdentityFile ~/.ssh/gfnq.pem

EOF
}

setup_bash_aliases() {
    sed -i '/^alias UPDATE=/d' ~/.bashrc
    echo "alias UPDATE='sudo -v && sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get autoremove --purge -y && sudo apt-get autoclean'" >> ~/.bashrc

    sed -i '/^alias SCRCPY=/d' ~/.bashrc
    echo "alias SCRCPY='/home/danish/DCIM/Code/scrcpy/scrcpy'" >> ~/.bashrc

    sed -i '/^NETDELAY() {/,/^}/d' ~/.bashrc

    cat >> ~/.bashrc <<'EOF'

NETDELAY() {
    local d
    d=$(ip -o link show | awk -F': ' '/enx/{print $2; exit}')

    if [[ "$1" == "reset" ]]; then
        sudo tc qdisc del dev "$d" root
    else
        sudo tc qdisc replace dev "$d" root netem delay "${1:-0}ms" "${2:-4}ms"
    fi
}
EOF
}

apt_system_refresh() {
    sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get autoremove --purge -y && sudo apt-get autoclean
}

enable_i386_architecture() {
    sudo dpkg --add-architecture i386
}

install_base_packages() {
    sudo apt-get update && sudo apt-get install -y adb curl vlc ffmpeg flatpak flatpak-xdg-utils gir1.2-flatpak-1.0 libflatpak0 fonts-noto-color-emoji fonts-noto-core gh git gnome-software-plugin-flatpak libnotify-bin libnotify4 nodejs pypy3 pypy3-venv python3 python3-venv tcpdump tree virt-manager zstd wget gpg
}

restore_grub_configuration() {
    sudo cp /usr/share/grub/default/grub /etc/default/grub && sudo chmod -x /etc/grub.d/05_debian_theme && sudo cp "$RESOURCES/backup-grub" /etc/default/grub && sudo update-grub
}

add_repo_brave_browser() {
    if ! command -v brave-browser-nightly >/dev/null 2>&1; then
        curl -fsS https://dl.brave.com/install.sh | FLAVOR=origin CHANNEL=nightly sh
    fi
}

add_repo_syncthing() {
    sudo mkdir -p /etc/apt/keyrings && sudo curl -L -o /etc/apt/keyrings/syncthing-archive-keyring.gpg https://syncthing.net/release-key.gpg && echo "deb [signed-by=/etc/apt/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable-v2" | sudo tee /etc/apt/sources.list.d/syncthing.list
}

add_repo_flathub() {
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

setup_virtualization() {
    sudo usermod -aG libvirt,kvm "$USER" && sudo systemctl enable --now libvirtd && sudo virsh net-autostart default || true
    sudo virsh net-info default | grep -q 'Active:.*yes' || sudo virsh net-start default || true
}

install_additional_packages() {
    sudo apt-get install -y syncthing gh
}

install_flatpak_packages() {
    flatpak install -y flathub org.kde.kdenlive net.ankiweb.Anki md.obsidian.Obsidian
}

rebuild_font_cache() {
    fc-cache -rv && sudo fc-cache -rv
}

setup_git_configuration() {
    git config --global init.defaultBranch main && git config --global user.name "$GIT_NAME" && git config --global user.email "$GIT_EMAIL"
}

add_zed() {
    if ! command -v zed >/dev/null 2>&1; then
        curl -f https://zed.dev/install.sh | sh
    fi
}

restore_gnome_settings() {
    dconf load / < "$RESOURCES/backup-gnome.dconf"
}

# ---

enable_i386_architecture
install_base_packages
setup_git_configuration
clone_repository

add_repo_brave_browser
add_repo_syncthing
# add_repo_protonvpn
add_repo_flathub

apt_system_refresh
install_additional_packages
add_zed
install_flatpak_packages

restore_grub_configuration
# restore_gnome_settings
setup_virtualization
setup_bash_aliases
setup_ssh_hosts

remove_bloat_packages
rebuild_font_cache

apt_system_refresh