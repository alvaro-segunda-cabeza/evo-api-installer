# evo-api-installer

Instala Evolution API + Redis + Postgres detrás de Traefik con SSL automático (Let's Encrypt).

## Requisitos

- VPS con Ubuntu 22.04+ (recomendado)
- Subdominio apuntando por DNS a la IP del servidor (Cloudflare OK)
- Puertos 80 y 443 abiertos hacia el VPS
- **Recomendado:** Usar imagen de Hetzner con Docker CE preinstalado (más rápido)
  - Si no tiene Docker, el script lo instalará automáticamente

## Instalación

```bash
git clone https://github.com/alvaro-segunda-cabeza/evo-api-installer.git
cd evo-api-installer
chmod +x install.sh
sudo ./install.sh
```

El script te preguntará:

1. Subdominio (ej: `api.midominio.com`)
2. Email para Let's Encrypt

Al terminar y emitirse el certificado, podrás acceder a:

- `https://TU_SUBDOMINIO`
- (Opcional) `https://TU_SUBDOMINIO/manager` si Evolution expone el panel ahí.
