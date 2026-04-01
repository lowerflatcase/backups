#!/usr/bin/env bash

exec 2> >(tee -a setup.log)

setup_usb_tethering() {
    for iface in /sys/class/net/enx*; do iface=${iface##*/}; sudo ip link set "$iface" up && sudo dhcpcd "$iface"; done
}

apt_system_refresh() {
    sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get autoremove --purge -y && sudo apt-get autoclean
}

enable_i386_architecture() {
    sudo dpkg --add-architecture i386
}

install_base_packages() {
    sudo apt-get install -y sway foot waybar mako-notifier thunar swaybg xwayland xdg-desktop-portal-wlr wl-clipboard brightnessctl grim slurp gammastep intel-gpu-tools firmware-intel-misc firmware-intel-sound pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber gstreamer1.0-pipewire obs-pipewire-audio-capture vlc-plugin-pipewire lxpolkit bluez bluez-alsa-utils bluez-cups bluez-hcidump bluez-meshd bluez-obexd bluez-tools bluez-firmware python3-bluez blueman jq tlp tlp-rdw xdg-desktop-portal xdg-desktop-portal-gtk libnotify-bin geoclue-2.0 mesa-utils fuzzel gir1.2-polkit-1.0 libpolkit-agent-1-0 libpolkit-gobject-1-0 libpolkit-qt5-1-1 libpolkit-qt6-1-1 polkitd pkexec tree curl wget virt-manager libxcb-xinerama0 libxcb-cursor0 libnss3 flatpak git python3 python3-venv tcpdump ffmpeg zstd fonts-noto-core fonts-atkinson-hyperlegible fonts-inter fonts-jetbrains-mono fonts-noto-color-emoji adb nodejs npm pypy3 pypy3-venv gh foot-extra-terminfo foot-terminfo swayidle swaylock swayimg swayosd thunar-data libthunarx-3-0 thunar-archive-plugin thunar-volman thunar-media-tags-plugin thunar-gtkhash thunar-font-manager thunar-vcs-plugin rabbitvcs-thunar grimshot libnotify4 flatpak-xdg-utils libflatpak0 libglib2.0-bin
}

install_network_manager() {
    sudo apt-get install -y network-manager network-manager-gnome network-manager-config-connectivity-debian network-manager-l10n network-manager-applet network-manager-iwd python3-networkmanager libproxy1-plugin-networkmanager
}

setup_sway_environment_and_autostart() {
    PROFILE="$HOME/.profile"

    SWAY_BLOCK='
# Sway environment and Wayland overrides
export XDG_CURRENT_DESKTOP=sway:wlroots
export _JAVA_AWT_WM_NONREPARENTING=1
export MOZ_DBUS_REMOTE=1

# Autostart Sway on login
if [ "$(tty)" = "/dev/tty1" ]; then
    read -p "Start Sway? [Y/n]: " -r
    if [[ -z "$REPLY" || "$REPLY" =~ ^[Yy]$ ]]; then
        exec dbus-run-session sway
    fi
fi
'

    grep -q "Start Sway?" "$PROFILE" 2>/dev/null || \
    echo "$SWAY_BLOCK" >> "$PROFILE"
}

# export ELECTRON_OZONE_PLATFORM_HINT=auto

configure_wayland_flags() {
    mkdir -p ~/.config
    echo "--ozone-platform-hint=auto" > ~/.config/brave-flags.conf
}

configure_gtk_font_rendering() {
    gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'; gsettings set org.gnome.desktop.interface font-hinting 'slight'; gsettings set org.gnome.desktop.interface font-rgba-order 'rgb'
}


configure_gtk_font_settings() {
    mkdir -p ~/.config/fontconfig ~/.config/gtk-3.0 ~/.config/gtk-4.0 && cp -f ./config-font ~/.config/fontconfig/fonts.conf && cp -f ./setting-gtk ~/.config/gtk-3.0/settings.ini && cp -f ./setting-gtk ~/.config/gtk-4.0/settings.ini
}

configure_mako_notifications() {
    mkdir -p ~/.config/mako && cp -f ./config-mako ~/.config/mako/config
}

configure_foot_terminal() {
    mkdir -p ~/.config/foot && cp -f ./config-foot ~/.config/foot/foot.ini
}

configure_gammastep() {
    mkdir -p ~/.config/gammastep && cp -f ./config-gammastep ~/.config/gammastep/config.ini
}

configure_fuzzel_launcher() {
    mkdir -p ~/.config/fuzzel && cp -f ./config-fuzzel ~/.config/fuzzel/fuzzel.ini
}

configure_sway() {
    mkdir -p ~/.config/sway && cp -f ./config-sway ~/.config/sway/config
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

create_cache_directory() {
    mkdir -p ~/.cache
}

configure_system_locale() {
    sudo update-locale LANG=en_IN.UTF-8
}

create_sl_directory() {
    mkdir -p "$HOME/Pictures/Screenshots (Laptop)"
}

configure_grim() {
    mkdir -p ~/.local/bin && cp -f ./config-grim ~/.local/bin/grim && chmod +x ~/.local/bin/grim
}

fix_delay() {
mkdir -p ~/.config/xdg-desktop-portal
cat <<EOF > ~/.config/xdg-desktop-portal/sway-portals.conf
[preferred]
default=wlr;gtk
EOF
}

# setup_usb_tethering

enable_i386_architecture

apt_system_refresh

install_local_deb_packages

install_base_packages

add_repo_brave_browser
add_repo_vscodium
add_repo_syncthing
add_repo_flathub

apt_system_refresh

install_additional_packages
install_flatpak_packages

setup_virtualization

create_cache_directory
# create_sl_directory

# setup_sway_environment_and_autostart

# configure_gtk_font_rendering
# configure_gtk_font_settings
configure_mako_notifications
configure_foot_terminal
# configure_gammastep
configure_fuzzel_launcher
configure_sway
# configure_grim

restore_grub_configuration
restore_tlp_configuration
restore_vscodium_configuration

install_battery_alert_service
setup_git_configuration
configure_system_locale

install_anki_package

install_network_manager

enable_system_services

# fix_delay

# configure_wayland_flags

rebuild_font_cache