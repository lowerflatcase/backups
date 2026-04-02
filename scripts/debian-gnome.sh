#!/usr/bin/env bash

exec 2> >(tee -a setup.log >&2)

remove_bloat_packages() {
    sudo apt purge -y baobab evolution firefox-esr gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-connections gnome-contacts gnome-disk-utility gnome-logs gnome-maps gnome-music gnome-sound-recorder gnome-system-monitor gnome-tour gnome-weather libreoffice* malcontent seahorse shotwell simple-scan totem yelp
}

apt_system_refresh() {
    sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get autoremove --purge -y && sudo apt-get autoclean
}

enable_i386_architecture() {
    sudo dpkg --add-architecture i386
}

install_base_packages() {
    sudo apt update && sudo apt install -y adb curl ffmpeg flatpak fonts-atkinson-hyperlegible fonts-inter fonts-jetbrains-mono fonts-noto-color-emoji fonts-noto-core gh git gnome-software-plugin-flatpak libflatpak0 libnotify-bin libnotify4 libnss3 libxcb-cursor0 libxcb-xinerama0 nodejs npm pypy3 pypy3-venv python3 python3-venv tcpdump tlp tlp-rdw tree virt-manager wget zstd && sudo systemctl enable tlp
}

restore_grub_configuration() {
    sudo chmod -x /etc/grub.d/05_debian_theme; sudo cp backup-grub /etc/default/grub && sudo update-grub
}

install_battery_alert_service() {
    mkdir -p ~/.local/bin ~/.config/systemd/user && cp -f notify-battery.sh ~/.local/bin/ && chmod +x ~/.local/bin/notify-battery.sh && cp -f notify-battery.service ~/.config/systemd/user/ && cp -f notify-battery.timer ~/.config/systemd/user/ && systemctl --user daemon-reload && systemctl --user enable notify-battery.timer
}

add_repo_brave_browser() {
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg && sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
}

add_repo_vscodium() {
    wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor | sudo dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg && echo -e 'Types: deb\nURIs: https://download.vscodium.com/debs\nSuites: vscodium\nComponents: main\nArchitectures: amd64 arm64\nSigned-by: /usr/share/keyrings/vscodium-archive-keyring.gpg' | sudo tee /etc/apt/sources.list.d/vscodium.sources
}

add_repo_syncthing() {
    sudo mkdir -p /etc/apt/keyrings && sudo curl -L -o /etc/apt/keyrings/syncthing-archive-keyring.gpg https://syncthing.net/release-key.gpg && echo "deb [signed-by=/etc/apt/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable-v2" | sudo tee /etc/apt/sources.list.d/syncthing.list
}

add_repo_flathub() {
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

install_anki_package() {
    tar --use-compress-program=unzstd -xf anki-*.tar.zst && cd anki-*/ && sudo mkdir -p /root/.config && sudo ./install.sh && cd - && rm -rf anki-*/
}

install_local_deb_packages() {
    sudo apt-get install ./*.deb -y
}

setup_virtualization() {
    sudo usermod -aG libvirt,kvm "$USER" && sudo systemctl enable --now libvirtd && sudo virsh net-start default && sudo virsh net-autostart default
}

install_additional_packages() {
    sudo apt-get install -y brave-browser codium syncthing proton-vpn-gnome-desktop
}

install_flatpak_packages() {
    flatpak install -y flathub org.kde.kdenlive
}

restore_vscodium_configuration() {
    mkdir -p ~/.config/VSCodium/User && cp -f setting-codium ~/.config/VSCodium/User/settings.json
}

restore_tlp_configuration() {
    sudo cp backup-tlp /etc/tlp.conf
}

rebuild_font_cache() {
    fc-cache -rv && sudo fc-cache -rv
}

setup_git_configuration() {
    git config --global init.defaultBranch main && git config --global user.name "Muhammad Danish" && git config --global user.email "ahdimsun@gmail.com"
}

enable_i386_architecture
remove_bloat_packages
restore_grub_configuration
install_battery_alert_service
install_local_deb_packages

install_base_packages

add_repo_brave_browser
add_repo_vscodium
add_repo_syncthing
add_repo_flathub

apt_system_refresh

install_additional_packages
install_flatpak_packages

install_anki_package
restore_vscodium_configuration
restore_tlp_configuration
setup_virtualization
setup_git_configuration
rebuild_font_cache

apt_system_refresh