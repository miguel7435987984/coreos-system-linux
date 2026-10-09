#!/usr/bin/env bash
# ==============================================================================
# CoreOS system Linux (Ubuntu 24.04 LTS Noble) - Gerador de Imagem ISO Oficial
# ==============================================================================
# Base minimalista imutável focada em Docker, Prius Terminal e baixo consumo de RAM.
# ==============================================================================

set -e

CODENAME="${CODENAME:-noble}"
MIRROR="${MIRROR:-http://archive.ubuntu.com/ubuntu/}"
KEYRING="${KEYRING:-/usr/share/keyrings/ubuntu-archive-keyring.gpg}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${SCRIPT_DIR}/build-workspace"
ROOTFS_DIR="${WORK_DIR}/rootfs"
IMAGE_DIR="${WORK_DIR}/image"
OUT_ISO="${SCRIPT_DIR}/coreos-24.04-amd64.iso"

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[COREOS LINUX]${NC} $1"
}

log_ok() {
    echo -e "${GREEN}[COREOS LINUX ✓]${NC} $1"
}

log_err() {
    echo -e "${RED}[COREOS LINUX ✗]${NC} $1"
}

if [ "$EUID" -ne 0 ]; then
    log_err "Execute este script como root: sudo ./build/build-iso.sh"
    exit 1
fi

log "==> [1/6] Verificando dependências de compilação..."
DEPS="debootstrap xorriso squashfs-tools grub-pc-bin grub-efi-amd64-bin mtools dosfstools"
for dep in $DEPS; do
    if ! command -v "$dep" &>/dev/null && ! dpkg -s "$dep" >/dev/null 2>&1; then
        log "Instalando dependência necessária: $dep"
        apt-get update && apt-get install -y "$dep"
    fi
done

log "==> [2/6] Preparando workspace em ${WORK_DIR}..."
mkdir -p "${ROOTFS_DIR}" "${IMAGE_DIR}/casper" "${IMAGE_DIR}/boot/grub/x86_64-efi" "${IMAGE_DIR}/EFI/BOOT" "${IMAGE_DIR}/.disk"
echo "CoreOS system Linux (Ubuntu 24.04 LTS Noble) - Release amd64" > "${IMAGE_DIR}/.disk/info"
touch "${IMAGE_DIR}/.disk/base_installable"

if [ ! -f "${ROOTFS_DIR}/bin/bash" ]; then
    log "Executando debootstrap para Ubuntu 24.04 LTS (${CODENAME})..."
    if [ ! -e "/usr/share/debootstrap/scripts/${CODENAME}" ]; then
        ln -sf gutsy "/usr/share/debootstrap/scripts/${CODENAME}" || true
    fi
    if ! debootstrap --arch=amd64 --variant=minbase --keyring="${KEYRING}" "${CODENAME}" "${ROOTFS_DIR}" "${MIRROR}"; then
        log_err "Falha no debootstrap! Exibindo logs de erro:"
        cat "${ROOTFS_DIR}/debootstrap/debootstrap.log" 2>/dev/null | tail -n 60 || true
        exit 1
    fi
else
    log_ok "Rootfs pré-existente encontrado em ${ROOTFS_DIR}. Pulando debootstrap..."
fi

log "==> [3/6] Montando sistemas de arquivos virtuais..."
mount --bind /dev "${ROOTFS_DIR}/dev"
mount --bind /run "${ROOTFS_DIR}/run"
mount -t devpts devpts "${ROOTFS_DIR}/dev/pts"
mount -t proc proc "${ROOTFS_DIR}/proc"
mount -t sysfs sysfs "${ROOTFS_DIR}/sys"

rm -f "${ROOTFS_DIR}/etc/resolv.conf"
echo "nameserver 8.8.8.8" > "${ROOTFS_DIR}/etc/resolv.conf"
echo "nameserver 1.1.1.1" >> "${ROOTFS_DIR}/etc/resolv.conf"

cleanup() {
    log "Desmontando sistemas de arquivos virtuais..."
    umount -lf "${ROOTFS_DIR}/dev/pts" 2>/dev/null || true
    umount -lf "${ROOTFS_DIR}/dev" 2>/dev/null || true
    umount -lf "${ROOTFS_DIR}/run" 2>/dev/null || true
    umount -lf "${ROOTFS_DIR}/proc" 2>/dev/null || true
    umount -lf "${ROOTFS_DIR}/sys" 2>/dev/null || true
}
trap cleanup EXIT

log "==> [4/6] Copiando arquivos de branding, aplicativos e configuração para o chroot..."
mkdir -p "${ROOTFS_DIR}/tmp/coreos-build"
cp -r "${SCRIPT_DIR}/apps" "${ROOTFS_DIR}/tmp/coreos-build/"
cp -r "${SCRIPT_DIR}/branding" "${ROOTFS_DIR}/tmp/coreos-build/"
cp -r "${SCRIPT_DIR}/config" "${ROOTFS_DIR}/tmp/coreos-build/"
cp "${SCRIPT_DIR}/build/customize.sh" "${ROOTFS_DIR}/tmp/coreos-build/customize.sh"
chmod +x "${ROOTFS_DIR}/tmp/coreos-build/customize.sh"

log "==> [5/6] Instalando pacotes essenciais, Kernel, Docker e customização no chroot..."
cat << 'EOF_CHROOT' | chroot "${ROOTFS_DIR}" /bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

cat << 'SOURCES' > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse
SOURCES

apt-get update

if [ -f /tmp/coreos-build/config/packages.list ]; then
    grep -v '^#' /tmp/coreos-build/config/packages.list | grep -v '^$' | xargs apt-get install -y --no-install-recommends
fi

bash /tmp/coreos-build/customize.sh

apt-get clean
EOF_CHROOT

log "Extraindo Kernel e Initramfs para a ISO..."
KERNEL_VER=$(ls -1 "${ROOTFS_DIR}/lib/modules" 2>/dev/null | tail -n 1)
if [ -n "${KERNEL_VER}" ]; then
    chroot "${ROOTFS_DIR}" update-initramfs -u -k "${KERNEL_VER}" || chroot "${ROOTFS_DIR}" update-initramfs -c -k "${KERNEL_VER}"
fi

VMLINUZ=$(ls -1t "${ROOTFS_DIR}/boot/vmlinuz-"* 2>/dev/null | head -n 1)
INITRD=$(ls -1t "${ROOTFS_DIR}/boot/initrd.img-"* 2>/dev/null | head -n 1)

if [ -n "${VMLINUZ}" ] && [ -f "${VMLINUZ}" ]; then
    cp -L "${VMLINUZ}" "${IMAGE_DIR}/casper/vmlinuz"
    chmod 644 "${IMAGE_DIR}/casper/vmlinuz"
    log_ok "Kernel copiado: ${VMLINUZ}"
fi

if [ -n "${INITRD}" ] && [ -f "${INITRD}" ]; then
    cp -L "${INITRD}" "${IMAGE_DIR}/casper/initrd"
    chmod 644 "${IMAGE_DIR}/casper/initrd"
    log_ok "Initrd copiado: ${INITRD}"
fi

rm -rf "${ROOTFS_DIR}/tmp/coreos-build"
rm -rf "${ROOTFS_DIR}/var/cache/apt/archives"/*

umount -lf "${ROOTFS_DIR}/dev/pts" 2>/dev/null || true
umount -lf "${ROOTFS_DIR}/dev" 2>/dev/null || true
umount -lf "${ROOTFS_DIR}/run" 2>/dev/null || true
umount -lf "${ROOTFS_DIR}/proc" 2>/dev/null || true
umount -lf "${ROOTFS_DIR}/sys" 2>/dev/null || true

log "==> [6/6] Criando squashfs e gerando imagem ISO híbrida ${OUT_ISO}..."
mksquashfs "${ROOTFS_DIR}" "${IMAGE_DIR}/casper/filesystem.squashfs" -comp xz -noappend -b 1M -all-root \
    -p "usr/bin/sudo.ws m 4755 0 0" \
    -p "usr/bin/sudo m 4755 0 0" \
    -p "usr/bin/pkexec m 4755 0 0" \
    -p "usr/lib/polkit-1/polkit-agent-helper-1 m 4755 0 0" \
    -p "etc/sudo.conf m 0644 0 0" \
    -p "etc/sudoers.d/99-coreos m 0440 0 0"

mkdir -p "${IMAGE_DIR}/boot/grub" "${IMAGE_DIR}/EFI/BOOT"

cat << 'EOF' > "${IMAGE_DIR}/boot/grub/grub.cfg"
set default="0"
set timeout=10

insmod all_video

if [ -z "$root" -o ! -f "($root)/casper/vmlinuz" ]; then
    if ! search --no-floppy --set=root --label COREOS_LINUX; then
        search --no-floppy --set=root --file /.disk/info
    fi
fi

menuentry "Experimentar ou Instalar o CoreOS system Linux (XFCE4 + Prius Terminal)" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper username=coreos user-fullname="CoreOS Linux" hostname=coreos locales=pt_BR.UTF-8 keyboard-configuration/layoutcode=br console-setup/layoutcode=br quiet splash ---
    initrd /casper/initrd
}

menuentry "CoreOS system Linux (Modo Seguro / Safe Graphics)" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper username=coreos user-fullname="CoreOS Linux" hostname=coreos locales=pt_BR.UTF-8 keyboard-configuration/layoutcode=br console-setup/layoutcode=br nomodeset quiet splash ---
    initrd /casper/initrd
}
EOF

cat << 'EOF' > "${IMAGE_DIR}/boot/grub/loopback.cfg"
set default="0"
set timeout=5

menuentry "CoreOS system Linux (Live)" {
    set gfxpayload=keep
    linux /casper/vmlinuz boot=casper username=coreos user-fullname="CoreOS Linux" hostname=coreos locales=pt_BR.UTF-8 keyboard-configuration/layoutcode=br console-setup/layoutcode=br iso-scan/filename=${iso_path} quiet splash ---
    initrd /casper/initrd
}
EOF

cat << 'EOF' > "${WORK_DIR}/early-grub.cfg"
if [ -z "$root" -o ! -f "($root)/casper/vmlinuz" ]; then
    if ! search --no-floppy --set=root --label COREOS_LINUX; then
        search --no-floppy --set=root --file /.disk/info
    fi
fi
set prefix=($root)/boot/grub
configfile $prefix/grub.cfg
EOF

mkdir -p "${IMAGE_DIR}/boot/grub/i386-pc" "${IMAGE_DIR}/boot/grub/x86_64-efi"
cp -r /usr/lib/grub/i386-pc/* "${IMAGE_DIR}/boot/grub/i386-pc/" 2>/dev/null || true
cp -r /usr/lib/grub/x86_64-efi/* "${IMAGE_DIR}/boot/grub/x86_64-efi/" 2>/dev/null || true

grub-mkstandalone \
    --format=x86_64-efi \
    --output="${IMAGE_DIR}/EFI/BOOT/BOOTX64.EFI" \
    --locales="" \
    --fonts="" \
    --modules="all_video efi_gop iso9660 fat exfat ext2 part_gpt part_msdos normal linux search search_label search_fs_file search_fs_uuid configfile test echo reboot" \
    "boot/grub/grub.cfg=${WORK_DIR}/early-grub.cfg"

dd if=/dev/zero of="${IMAGE_DIR}/boot/grub/efi.img" bs=1M count=10
mkfs.vfat "${IMAGE_DIR}/boot/grub/efi.img"
mmd -i "${IMAGE_DIR}/boot/grub/efi.img" ::EFI
mmd -i "${IMAGE_DIR}/boot/grub/efi.img" ::EFI/BOOT
mcopy -i "${IMAGE_DIR}/boot/grub/efi.img" "${IMAGE_DIR}/EFI/BOOT/BOOTX64.EFI" ::EFI/BOOT/

grub-mkimage \
    --format=i386-pc-eltorito \
    --output="${IMAGE_DIR}/boot/grub/bios.img" \
    --prefix=/boot/grub \
    iso9660 biosdisk search search_label search_fs_file normal test linux

log "Gerando imagem ISO híbrida oficial com xorriso..."
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -r \
    -J \
    -volid "COREOS_LINUX" \
    -eltorito-boot boot/grub/bios.img \
    -eltorito-catalog boot/grub/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -output "${OUT_ISO}" \
    "${IMAGE_DIR}"

log_ok "ISO do CoreOS system Linux gerada com sucesso em: ${OUT_ISO}"
