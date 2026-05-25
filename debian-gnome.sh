#!/usr/bin/env bash

set -eo pipefail

GREEN='\033[0;32m'
NC='\033[0m'

sudo -v

read -rp "Enter Git name: " GIT_NAME
read -rp "Enter Git email: " GIT_EMAIL
read -rp "Enter server IP: " SERVER_IP
read -rp "Enter SSH username [admin]: " SSH_USER

SSH_USER="${SSH_USER:-admin}"

REPO_DIR="$HOME/backups"
RESOURCES="$REPO_DIR/resources"

clone_repository() {
    echo -e "${GREEN}===> Cloning repository...${NC}" >&2
    rm -rf "$REPO_DIR" && git clone https://github.com/lowerflatcase/backups.git "$REPO_DIR"
}

remove_bloat_packages() {
    echo -e "${GREEN}===> Removing bloat packages...${NC}" >&2
    sudo apt-get purge -y gnome-calculator baobab evolution firefox-esr gnome-calendar gnome-characters gnome-clocks gnome-connections gnome-contacts gnome-disk-utility gnome-logs gnome-maps gnome-music gnome-sound-recorder gnome-system-monitor gnome-tour gnome-weather 'libreoffice*' malcontent seahorse shotwell simple-scan totem yelp gnome-snapshot gnome-font-viewer gnome-text-editor
}

setup_ssh_hosts() {
    echo -e "${GREEN}===> Setting up SSH hosts...${NC}" >&2

    mkdir -p ~/.ssh
    touch ~/.ssh/config
    chmod 600 ~/.ssh/config

    sed -i '/^Host gfnq$/,/^$/d' ~/.ssh/config

    cat >> ~/.ssh/config <<EOF

Host gfnq
    HostName $SERVER_IP
    User $SSH_USER
    IdentityFile ~/.ssh/gfnq.pem

EOF
}

setup_bash_aliases() {
    echo -e "${GREEN}===> Setting up bash aliases...${NC}" >&2

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
    echo -e "${GREEN}===> Refreshing system packages...${NC}" >&2
    sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get autoremove --purge -y && sudo apt-get autoclean
}

enable_i386_architecture() {
    echo -e "${GREEN}===> Enabling i386 architecture...${NC}" >&2
    sudo dpkg --add-architecture i386
}

install_base_packages() {
    echo -e "${GREEN}===> Installing base packages...${NC}" >&2
    sudo apt-get update && sudo apt-get install -y adb curl vlc ffmpeg flatpak flatpak-xdg-utils gir1.2-flatpak-1.0 libflatpak0 fonts-noto-color-emoji fonts-noto-core gh git gnome-software-plugin-flatpak libnotify-bin libnotify4 nodejs pypy3 pypy3-venv python3 python3-venv tcpdump tlp tlp-rdw tree virt-manager zstd wget gpg
}

restore_grub_configuration() {
    echo -e "${GREEN}===> Restoring GRUB configuration...${NC}" >&2
    sudo cp /usr/share/grub/default/grub /etc/default/grub && sudo chmod -x /etc/grub.d/05_debian_theme && sudo cp "$RESOURCES/backup-grub" /etc/default/grub && sudo update-grub
}

add_repo_brave_browser() {
    echo -e "${GREEN}===> Adding Brave Nightly repository...${NC}" >&2
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-nightly-archive-keyring.gpg https://brave-browser-apt-nightly.s3.brave.com/brave-browser-nightly-archive-keyring.gpg && sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-nightly.sources https://brave-browser-apt-nightly.s3.brave.com/brave-browser.sources
}

add_repo_syncthing() {
    echo -e "${GREEN}===> Adding Syncthing repository...${NC}" >&2
    sudo mkdir -p /etc/apt/keyrings && sudo curl -L -o /etc/apt/keyrings/syncthing-archive-keyring.gpg https://syncthing.net/release-key.gpg && echo "deb [signed-by=/etc/apt/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable-v2" | sudo tee /etc/apt/sources.list.d/syncthing.list
}

add_repo_protonvpn() {
    echo -e "${GREEN}===> Adding ProtonVPN repo...${NC}" >&2
    (cd "$RESOURCES" && wget -qO protonvpn-stable-release_1.0.8_all.deb https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.8_all.deb && sudo dpkg -i ./protonvpn-stable-release_1.0.8_all.deb)
}

add_repo_flathub() {
    echo -e "${GREEN}===> Adding Flathub repository...${NC}" >&2
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

setup_virtualization() {
    echo -e "${GREEN}===> Setting up virtualization...${NC}" >&2
    sudo usermod -aG libvirt,kvm "$USER" && sudo systemctl enable --now libvirtd && sudo virsh net-autostart default || true
    sudo virsh net-info default | grep -q 'Active:.*yes' || sudo virsh net-start default || true
}

install_additional_packages() {
    echo -e "${GREEN}===> Installing additional packages (Brave Origin Beta, Syncthing, etc)...${NC}" >&2
    sudo apt-get install -y brave-origin-nightly syncthing proton-vpn-gnome-desktop codium
}

install_flatpak_packages() {
    echo -e "${GREEN}===> Installing Flatpak packages...${NC}" >&2
    flatpak install -y flathub org.kde.kdenlive net.ankiweb.Anki md.obsidian.Obsidian
}

restore_codium_configuration(){
    echo -e "${GREEN}===> Restoring VSCodium configuration...${NC}" >&2
    mkdir -p ~/.config/VSCodium/User && cp -f "$RESOURCES/setting-codium" ~/.config/VSCodium/User/settings.json
}

rebuild_font_cache() {
    echo -e "${GREEN}===> Rebuilding font cache...${NC}" >&2
    fc-cache -rv && sudo fc-cache -rv
}

setup_git_configuration() {
    echo -e "${GREEN}===> Setting up Git configuration...${NC}" >&2
    git config --global init.defaultBranch main && git config --global user.name "$GIT_NAME" && git config --global user.email "$GIT_EMAIL"
}

add_zed() {
    echo -e "${GREEN}===> Adding Zed...${NC}" >&2
    mkdir -p ~/.local/{bin,share/applications} && curl -fL "https://zed.dev/api/releases/stable/latest/zed-linux-x86_64.tar.gz" -o /tmp/zed.tar.gz && rm -rf ~/.local/zed.app && tar -xzf /tmp/zed.tar.gz -C ~/.local/ && ln -sf ~/.local/zed.app/bin/zed ~/.local/bin/zed && cp ~/.local/zed.app/share/applications/dev.zed.Zed.desktop ~/.local/share/applications/ && sed -i "s|Icon=zed|Icon=$HOME/.local/zed.app/share/icons/hicolor/512x512/apps/zed.png|g; s|Exec=zed|Exec=$HOME/.local/zed.app/bin/zed|g" ~/.local/share/applications/dev.zed.Zed.desktop
}

restore_gnome_settings() {
    echo -e "${GREEN}===> Restoring GNOME settings...${NC}" >&2
    dconf load / < "$RESOURCES/backup-gnome.dconf"
}

# ---

enable_i386_architecture
install_base_packages
setup_git_configuration
clone_repository

add_repo_brave_browser
add_repo_syncthing
add_repo_protonvpn
add_repo_flathub

apt_system_refresh
install_additional_packages
add_zed
install_flatpak_packages

restore_codium_configuration
restore_grub_configuration
restore_gnome_settings
setup_virtualization
setup_bash_aliases
setup_ssh_hosts

remove_bloat_packages
rebuild_font_cache

apt_system_refresh

echo -e "${GREEN}===> All done! Please log out and back in (or reboot) for all changes to take effect.${NC}" >&2
