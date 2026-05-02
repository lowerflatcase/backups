#!/usr/bin/env bash

set -euo pipefail

GREEN='\033[0;32m'
NC='\033[0m'

sudo -v

REPO_DIR="$HOME/backups"
RESOURCES="$REPO_DIR/resources"

clone_repository() {
    echo -e "${GREEN}===> Cloning repository...${NC}" >&2
    rm -rf "$REPO_DIR" && git clone https://github.com/lowerflatcase/backups.git "$REPO_DIR"
}

remove_bloat_packages() {
    echo -e "${GREEN}===> Removing bloat packages...${NC}" >&2
    sudo apt-get purge -y evince gnome-calculator baobab evolution firefox-esr gnome-calendar gnome-characters gnome-clocks gnome-connections gnome-contacts gnome-disk-utility gnome-logs gnome-maps gnome-music gnome-sound-recorder gnome-system-monitor gnome-tour gnome-weather 'libreoffice*' malcontent seahorse shotwell simple-scan totem yelp gnome-snapshot gnome-font-viewer gnome-text-editor loupe
}

setup_bash_aliases() {
    echo -e "${GREEN}===> Setting up bash aliases...${NC}" >&2
    sed -i '/^alias update=/d' ~/.bashrc && echo "alias update='sudo -v && sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get autoremove --purge -y && sudo apt-get autoclean'" >> ~/.bashrc
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
    sudo apt-get update && sudo apt-get install -y adb curl vlc ffmpeg flatpak flatpak-xdg-utils gir1.2-flatpak-1.0 libflatpak0 fonts-noto-color-emoji fonts-noto-core gh git gnome-software-plugin-flatpak libnotify-bin libnotify4 nodejs npm pypy3 pypy3-venv python3 python3-venv tcpdump tlp tlp-rdw tree virt-manager zstd wget gpg
}

restore_grub_configuration() {
    echo -e "${GREEN}===> Restoring GRUB configuration...${NC}" >&2
    sudo cp /usr/share/grub/default/grub /etc/default/grub && sudo chmod -x /etc/grub.d/05_debian_theme && sudo cp "$RESOURCES/backup-grub" /etc/default/grub && sudo update-grub
}

install_battery_alert_service() {
    echo -e "${GREEN}===> Installing battery alert service...${NC}" >&2
    mkdir -p ~/.local/bin ~/.config/systemd/user && cp -f "$RESOURCES/notify-battery.sh" ~/.local/bin/ && chmod +x ~/.local/bin/notify-battery.sh && cp -f "$RESOURCES/notify-battery.service" ~/.config/systemd/user/ && cp -f "$RESOURCES/notify-battery.timer" ~/.config/systemd/user/ && systemctl --user daemon-reload && systemctl --user enable notify-battery.timer
}

add_repo_brave_browser() {
    echo -e "${GREEN}===> Adding Brave Browser repository...${NC}" >&2
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg && sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
}

add_repo_syncthing() {
    echo -e "${GREEN}===> Adding Syncthing repository...${NC}" >&2
    sudo mkdir -p /etc/apt/keyrings && sudo curl -L -o /etc/apt/keyrings/syncthing-archive-keyring.gpg https://syncthing.net/release-key.gpg && echo "deb [signed-by=/etc/apt/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable-v2" | sudo tee /etc/apt/sources.list.d/syncthing.list
}

add_repo_protonvpn() {
    echo -e "${GREEN}===> Adding ProtonVPN repo...${NC}" >&2
    (cd "$RESOURCES" && wget https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.8_all.deb && sudo dpkg -i ./protonvpn-stable-release_1.0.8_all.deb)
}

add_repo_flathub() {
    echo -e "${GREEN}===> Adding Flathub repository...${NC}" >&2
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

setup_virtualization() {
    echo -e "${GREEN}===> Setting up virtualization...${NC}" >&2
    sudo usermod -aG libvirt,kvm "$USER" && sudo systemctl enable --now libvirtd && sudo virsh net-autostart default && sudo virsh net-start default || true
}

install_additional_packages() {
    echo -e "${GREEN}===> Installing additional packages (Brave, Syncthing, etc)...${NC}" >&2
    sudo apt-get install -y brave-browser syncthing proton-vpn-gnome-desktop codium
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
    git config --global init.defaultBranch main && git config --global user.name "Muhammad Danish" && git config --global user.email "ahdimsun@gmail.com"
}

add_repo_codium() {
    echo -e "${GREEN}===> Adding VSCodium repository...${NC}" >&2
    wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor | sudo dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg && echo -e 'Types: deb\nURIs: https://download.vscodium.com/debs\nSuites: vscodium\nComponents: main\nArchitectures: amd64 arm64\nSigned-by: /usr/share/keyrings/vscodium-archive-keyring.gpg' | sudo tee /etc/apt/sources.list.d/vscodium.sources
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
add_repo_codium
add_repo_protonvpn
add_repo_flathub

apt_system_refresh
install_additional_packages
install_flatpak_packages

restore_codium_configuration
restore_grub_configuration
restore_gnome_settings
install_battery_alert_service
setup_virtualization
setup_bash_aliases

remove_bloat_packages
rebuild_font_cache

apt_system_refresh

echo -e "${GREEN}===> All done! Please log out and back in (or reboot) for all changes to take effect.${NC}" >&2
