#!/usr/bin/env bash

exec 2> >(tee -a setup.log)

apt_system_refresh() {
    sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get autoremove --purge -y && sudo apt-get autoclean
}

enable_i386_architecture() {
    sudo dpkg --add-architecture i386
}

install_base_packages() {
    sudo apt-get install foot foot-terminfo foot-extra-terminfo sway sway-backgrounds swaybg swayidle swayimg swaylock swayosd libnotify-bin libnotify4 waybar mako-notifier thunar libthunarx-3-0 thunar-archive-plugin thunar-data thunar-font-manager thunar-gtkhash thunar-media-tags-plugin thunar-volman wl-clipboard grim slurp grimshot brightnessctl gammastep xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr pipewire gstreamer1.0-pipewire libpipewire-0.3-0t64 libpipewire-0.3-common libpipewire-0.3-modules libpipewire-0.3-modules-x11 obs-pipewire-audio-capture pipewire-alsa pipewire-audio pipewire-audio-client-libraries pipewire-bin pipewire-jack pipewire-libcamera pipewire-pulse pipewire-v4l2 vlc-plugin-pipewire libwireplumber-0.5-0 wireplumber bluez bluez-alsa-utils bluez-firmware bluez-obexd bluez-tools libasound2-plugin-bluez python3-bluez tlp tlp-rdw geoclue-2.0 firmware-intel-misc firmware-intel-sound firmware-intel-graphics tree curl wget jq tcpdump ffmpeg zstd git python3 python3-venv pypy3 pypy3-venv nodejs npm gh adb virt-manager fonts-noto-core fonts-noto-color-emoji fonts-atkinson-hyperlegible fonts-inter fonts-jetbrains-mono firmware-intel-graphics firmware-intel-misc firmware-intel-sound intel-media-va-driver intel-media-va-driver-non-free intel-microcode intel-hdcp libxcb-xinerama0 libxcb-cursor0 libnss3 flatpak flatpak-xdg-utils gir1.2-flatpak-1.0 libflatpak0 lxpolkit polkitd
}

install_network_manager() {
    sudo apt-get install network-manager network-manager-applet network-manager-openvpn network-manager-iwd network-manager-config-connectivity-debian libproxy1-plugin-networkmanager python3-networkmanager
}

restore_grub_configuration() {
    sudo cp ./backup-grub /etc/default/grub && sudo update-grub
}

install_battery_alert_service() {
    mkdir -p ~/.local/bin ~/.config/systemd/user && cp -f ./notify-battery.sh ~/.local/bin/ && chmod +x ~/.local/bin/notify-battery.sh && cp -f ./notify-battery.service ~/.config/systemd/user/ && cp -f ./notify-battery.timer ~/.config/systemd/user/ && systemctl --user daemon-reload && systemctl --user enable notify-battery.timer
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
    flatpak install -y flathub org.kde.kdenlive md.obsidian.Obsidian io.mrarm.mcpelauncher
}

restore_vscodium_configuration() {
    mkdir -p ~/.config/VSCodium/User && cp -f ./setting-codium ~/.config/VSCodium/User/settings.json
}

restore_tlp_configuration() {
    sudo cp ./backup-tlp /etc/tlp.conf
}

rebuild_font_cache() {
    fc-cache -rv && sudo fc-cache -rv
}

setup_git_configuration() {
    git config --global init.defaultBranch main && git config --global user.name "Muhammad Danish" && git config --global user.email "ahdimsun@gmail.com"
}

enable_system_services() {
    sudo systemctl enable NetworkManager bluetooth tlp
}



enable_i386_architecture
install_local_deb_packages
apt_system_refresh
install_base_packages
add_repo_brave_browser
add_repo_vscodium
add_repo_syncthing
add_repo_flathub
apt_system_refresh
install_additional_packages
install_flatpak_packages

install_anki_package
setup_virtualization
restore_vscodium_configuration
restore_tlp_configuration
restore_grub_configuration
install_battery_alert_service
rebuild_font_cache
setup_git_configuration
install_network_manager
enable_system_services