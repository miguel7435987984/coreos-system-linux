# CoreOS system Linux (Ubuntu 24.04 LTS Noble)

Sistema operacional minimalista, rápido e elegante com interface gráfica XFCE4 moderna, Prius Terminal nativo e proteção anti-OOM.

## 🚀 Recursos Principais:
- **Base:** Ubuntu 24.04 LTS (Noble Numbat).
- **Interface Gráfica:** XFCE4 Moderno com LightDM autologin (consumo em repouso: ~350MB de RAM).
- **Prius Terminal & Fastfetch:** Terminal padrão com suporte nativo a Drag and Drop e Fastfetch Wine Edition integrado.
- **Identidade Própria:** Sistema com os-release oficial CoreOS (sem identificação genérica do Ubuntu).
- **Proteção Anti-Crash (Anti-OOM):** `systemd-oomd` desativado e `zram-tools` ativado (50% de swap comprimido LZ4).
- **Visual Wine Edition:** Wallpaper exclusivo e tema escuro moderno integrado.
- **Boot Splash Plymouth:** Animação fluída neon de 60 quadros com logotipo CoreOS.

## 🛠️ Como Compilar a ISO:
```bash
sudo ./build/build-iso.sh
```
A ISO final será gerada na raiz do projeto: `coreos-24.04-amd64.iso`.
