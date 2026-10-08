# CoreOS system Linux (Ubuntu 24.04 LTS Noble)

Sistema operacional minimalista imutável otimizado para containers Docker e baixo consumo de memória RAM.

## 🚀 Recursos Principais:
- **Base:** Ubuntu 24.04 LTS (Noble Numbat).
- **Interface Gráfica:** Ultra-leve com Openbox + Prius Terminal (consumo em repouso: ~200MB de RAM).
- **Docker Nativo:** Docker CE, containerd e docker-compose integrados.
- **Proteção Anti-Crash (Anti-OOM):** `systemd-oomd` desativado, impedindo que processos e containers sejam mortos repentinamente.
- **zram-tools Ativado:** 50% de swap comprimido em memória RAM com LZ4 para velocidade máxima.
- **Drag and Drop Nativo:** Suporte completo para arrastar pastas e arquivos diretamente para o Prius Terminal.

## 🛠️ Como Compilar a ISO:
```bash
sudo ./build/build-iso.sh
```
A ISO final será gerada na raiz do projeto: `coreos-24.04-amd64.iso`.
