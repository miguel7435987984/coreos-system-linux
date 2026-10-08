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

# 5. Configuração do Docker Nativo
systemctl enable docker 2>/dev/null || true
systemctl enable containerd 2>/dev/null || true
groupadd -f docker
usermod -aG docker coreos 2>/dev/null || true

# 6. Sessão Gráfica Minimalista: NODM + Openbox + Prius Terminal
cat << 'EOF_NODM' > /etc/default/nodm
NODM_ENABLED=true
NODM_USER=coreos
NODM_XSESSION=/etc/X11/Xsession
NODM_X_OPTIONS="-nolisten tcp"
NODM_MIN_SESSION_TIME=60
EOF_NODM

mkdir -p /etc/xdg/openbox
cat << 'EOF_OPENBOX' > /etc/xdg/openbox/autostart
# Inicia suporte a clipboard e redimensionamento no VirtualBox
which VBoxClient-all >/dev/null 2>&1 && VBoxClient-all &

# Aplica o Wallpaper oficial Wine Edition
if [ -f /usr/share/backgrounds/coreos/coreos-default.png ]; then
    feh --bg-fill /usr/share/backgrounds/coreos/coreos-default.png &
fi

# Inicia Prius Terminal em tela cheia / maximizado
prius &
EOF_OPENBOX
chmod +x /etc/xdg/openbox/autostart

# 7. Instalação do Prius Terminal e Branding
if [ -d /tmp/coreos-build/apps/prius-terminal ]; then
    bash /tmp/coreos-build/apps/prius-terminal/install.sh
fi

if [ -d /tmp/coreos-build/branding/icons ]; then
    mkdir -p /usr/share/pixmaps /usr/share/icons/hicolor/scalable/apps
    cp /tmp/coreos-build/branding/icons/*.svg /usr/share/icons/hicolor/scalable/apps/ 2>/dev/null || true
    cp /tmp/coreos-build/branding/icons/*.png /usr/share/pixmaps/ 2>/dev/null || true
fi

if [ -d /tmp/coreos-build/branding/wallpaper ]; then
    mkdir -p /usr/share/backgrounds/coreos
    cp /tmp/coreos-build/branding/wallpaper/* /usr/share/backgrounds/coreos/ 2>/dev/null || true
fi

# 8. Plymouth Boot Splash (crDroid 4 Dots + CoreOS Logo)
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
