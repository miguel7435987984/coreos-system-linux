#!/usr/bin/env bash
# ==============================================================================
# CoreOS system Linux (Ubuntu 24.04 LTS Noble) - Live Customization Hook
# ==============================================================================

set -e
export DEBIAN_FRONTEND=noninteractive

echo "==> [CoreOS Hook] Configurando Sistema CoreOS Linux..."

# 1. Hostname, Hosts & Locales
echo "coreos" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1   localhost
127.0.1.1   coreos
::1         localhost ip6-localhost ip6-loopback
EOF

if [ -x "$(command -v locale-gen)" ]; then
    locale-gen pt_BR.UTF-8 en_US.UTF-8 || true
    update-locale LANG=pt_BR.UTF-8 LC_MESSAGES=POSIX || true
fi

ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
echo "America/Sao_Paulo" > /etc/timezone

# 1.1 Branding do Sistema (CoreOS Wine Edition - os-release e issue)
if [ -f /tmp/coreos-build/branding/os-release ]; then
    mkdir -p /etc /usr/lib
    if [ -x "$(command -v dpkg-divert)" ]; then
        dpkg-divert --package coreos-branding --divert /usr/lib/os-release.ubuntu --rename /usr/lib/os-release || true
        dpkg-divert --package coreos-branding --divert /etc/os-release.ubuntu --rename /etc/os-release || true
    fi
    cp /tmp/coreos-build/branding/os-release /usr/lib/os-release
    cp /tmp/coreos-build/branding/os-release /etc/os-release
fi

cat << 'EOF_ISSUE' > /etc/issue
CoreOS system Linux 1.0 (Wine Edition) \n \l

EOF_ISSUE
cp /etc/issue /etc/issue.net

mkdir -p /usr/sbin
cat << 'EOF' > /usr/sbin/install-keymap
#!/bin/sh
exit 0
EOF
chmod +x /usr/sbin/install-keymap

# 2. Configuração Casper (Sessão Live)
cat << 'EOF_CASPER' > /etc/casper.conf
export USERNAME="coreos"
export USERFULLNAME="CoreOS Linux"
export HOST="coreos"
export BUILD_SYSTEM="Ubuntu"
export FLAVOUR="CoreOS"
EOF_CASPER

# 3. Permissões SUID e Usuário Live
mkdir -p /etc/sudoers.d
echo "coreos ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-coreos
chmod 0440 /etc/sudoers.d/99-coreos

chmod 4755 /usr/bin/pkexec /usr/bin/sudo 2>/dev/null || true
chown root:root /usr/bin/pkexec /usr/bin/sudo 2>/dev/null || true

# 4. Anti-Crash OOM: Desativação total do systemd-oomd e Ativação de ZRAM
systemctl mask systemd-oomd 2>/dev/null || true
systemctl disable systemd-oomd 2>/dev/null || true
echo "    ✓ systemd-oomd desativado (imune a mortes de processos por falta de RAM)"

mkdir -p /etc/default
cat << 'EOF_ZRAM' > /etc/default/zramswap
ALGO=lz4
PERCENT=50
PRIORITY=100
EOF_ZRAM
echo "    ✓ zram-tools configurado (50% de RAM compactada em swap rápido)"

# 5. Configuração do LightDM (Login Automático para o Usuário Live)
mkdir -p /etc/lightdm/lightdm.conf.d
cat << 'EOF_LIGHTDM' > /etc/lightdm/lightdm.conf
[Seat:*]
autologin-guest=false
autologin-user=coreos
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-gtk-greeter
EOF_LIGHTDM

# Garante que o serviço lightdm está habilitado como gerenciador padrão
systemctl enable lightdm 2>/dev/null || true
if [ -f /etc/X11/default-display-manager ]; then
    echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
fi

# 6. Instalação de Aplicativos Oficiais (Prius Terminal & get-install)
if [ -d /tmp/coreos-build/apps/prius-terminal ]; then
    bash /tmp/coreos-build/apps/prius-terminal/install.sh
fi

if [ -d /tmp/coreos-build/apps/get-install ]; then
    bash /tmp/coreos-build/apps/get-install/install.sh
fi

# Configuração do Repositório Mozilla Oficial para Firefox nativo (.deb tradicional sem Snap)
mkdir -p /etc/apt/keyrings /etc/apt/preferences.d /etc/apt/sources.list.d
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null || true

cat << 'SOURCES' > /etc/apt/sources.list.d/mozilla.sources
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
SOURCES

cat << 'PREF' > /etc/apt/preferences.d/mozilla
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
PREF

apt-get update -qq || true
apt-get install -y firefox firefox-l10n-pt-br || true

if [ -d /tmp/coreos-build/branding/icons ]; then
    mkdir -p /usr/share/pixmaps /usr/share/icons/hicolor/scalable/apps
    cp /tmp/coreos-build/branding/icons/*.svg /usr/share/icons/hicolor/scalable/apps/ 2>/dev/null || true
    cp /tmp/coreos-build/branding/icons/*.png /usr/share/pixmaps/ 2>/dev/null || true
fi

if [ -d /tmp/coreos-build/branding/wallpaper ]; then
    mkdir -p /usr/share/backgrounds/coreos /usr/share/backgrounds/xfce
    cp /tmp/coreos-build/branding/wallpaper/* /usr/share/backgrounds/coreos/ 2>/dev/null || true
    # Substitui wallpaper padrão do XFCE pelo CoreOS Wine Edition
    cp /usr/share/backgrounds/coreos/coreos-default.png /usr/share/backgrounds/xfce/xfce-blue.jpg 2>/dev/null || true
    cp /usr/share/backgrounds/coreos/coreos-default.png /usr/share/backgrounds/xfce/xfce-teal.jpg 2>/dev/null || true
    cp /usr/share/backgrounds/coreos/coreos-default.png /usr/share/backgrounds/xfce/coreos-default.png 2>/dev/null || true
fi

# 7. Configuração Padrão do XFCE (Tema Escuro, Wallpaper e Painel)
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat << 'EOF_XFCE_DESKTOP' > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="image-path" type="string" value="/usr/share/backgrounds/coreos/coreos-default.png"/>
        <property name="last-image" type="string" value="/usr/share/backgrounds/coreos/coreos-default.png"/>
        <property name="image-style" type="int" value="5"/>
      </property>
    </property>
  </property>
</channel>
EOF_XFCE_DESKTOP

# Tema escuro e ícones modernos por padrão no XFCE
cat << 'EOF_XFCE_UI' > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Greybird-dark"/>
    <property name="IconThemeName" type="string" value="Yaru-dark"/>
  </property>
</channel>
EOF_XFCE_UI

# Prius Terminal como emulador de terminal padrão do sistema
update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/local/bin/prius 100 || true
update-alternatives --set x-terminal-emulator /usr/local/bin/prius || true

# 7.1 Instalação e Configuração do Fastfetch Oficial (Wine Edition)
if ! command -v fastfetch &>/dev/null; then
    wget -q "https://github.com/fastfetch-cli/fastfetch/releases/download/2.38.0/fastfetch-linux-amd64.deb" -O /tmp/fastfetch.deb 2>/dev/null || true
    if [ -f /tmp/fastfetch.deb ]; then
        dpkg -i /tmp/fastfetch.deb || apt-get install -fy || true
        rm -f /tmp/fastfetch.deb
    fi
fi

mkdir -p /etc/fastfetch
if [ -d /tmp/coreos-build/config/fastfetch ]; then
    cp -r /tmp/coreos-build/config/fastfetch/* /etc/fastfetch/ || true
fi

cat << 'EOF_BASH' >> /etc/bash.bashrc

# CoreOS Fastfetch Wine Edition
alias fastfetch='fastfetch -c /etc/fastfetch/config.jsonc'
alias neofetch='fastfetch -c /etc/fastfetch/config.jsonc'
alias coreos-info='fastfetch -c /etc/fastfetch/config.jsonc'
alias get='get-install'

if [ -t 1 ] && [ -x /usr/bin/fastfetch ]; then
    fastfetch -c /etc/fastfetch/config.jsonc
fi
EOF_BASH

# Configura auto-início do VBoxClient no XFCE (Clipboard compartilhado e redimensionamento automático)
mkdir -p /etc/xdg/autostart
cat << 'EOF_VBOX' > /etc/xdg/autostart/vboxclient.desktop
[Desktop Entry]
Type=Application
Name=VirtualBox Guest Services
Exec=/usr/bin/VBoxClient-all
OnlyShowIn=XFCE;
EOF_VBOX

# 8. Configuração de Rede (NetworkManager & Netplan para VMs e Máquinas Físicas)
mkdir -p /etc/netplan
cat <<'EOF' > /etc/netplan/01-network-manager-all.yaml
network:
  version: 2
  renderer: NetworkManager
EOF
chmod 600 /etc/netplan/01-network-manager-all.yaml

# Força o NetworkManager a gerenciar todas as interfaces (Ethernet, Wi-Fi, interfaces virtuais)
mkdir -p /etc/NetworkManager/conf.d
cat <<'EOF' > /etc/NetworkManager/conf.d/10-globally-managed-devices.conf
[keyfile]
unmanaged-devices=none
EOF

cat <<'EOF' > /etc/NetworkManager/NetworkManager.conf
[main]
plugins=ifupdown,keyfile
dns=systemd-resolved

[ifupdown]
managed=true

[device]
wifi.scan-rand-mac-address=no
EOF

# Permissão no Polkit para controle de rede na sessão Live sem senha
mkdir -p /etc/polkit-1/rules.d
cat <<'EOF' > /etc/polkit-1/rules.d/99-coreos-networkmanager.rules
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.NetworkManager.") == 0) {
        return polkit.Result.YES;
    }
});
EOF

# Habilita serviços essenciais de rede
systemctl enable NetworkManager 2>/dev/null || true
systemctl enable systemd-resolved 2>/dev/null || true
systemctl enable wpa_supplicant 2>/dev/null || true

if [ -x "$(command -v netplan)" ]; then
    netplan generate 2>/dev/null || true
fi

# 9. Plymouth Boot Splash (Logotipo Oficial CoreOS)
mkdir -p /usr/share/plymouth/themes/spinner /usr/share/plymouth/themes/bgrt
if [ -d /tmp/coreos-build/branding/plymouth/spinner ]; then
    cp -r /tmp/coreos-build/branding/plymouth/spinner/* /usr/share/plymouth/themes/spinner/ || true
fi
if [ -d /tmp/coreos-build/branding/plymouth/bgrt ]; then
    cp -r /tmp/coreos-build/branding/plymouth/bgrt/* /usr/share/plymouth/themes/bgrt/ || true
fi

if [ -x "$(command -v plymouth-set-default-theme)" ]; then
    plymouth-set-default-theme bgrt || plymouth-set-default-theme spinner || true
fi

# 8. Limpeza de pacotes temporários
apt-get clean
rm -rf /var/lib/apt/lists/* || true
echo "==> [CoreOS Hook] Customização concluída com sucesso!"
