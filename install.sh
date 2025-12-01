#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

CHECK_APP_MAX_ATTEMPTS=12
CHECK_APP_DELAY_SECONDS=10

echo -e "${YELLOW}=== evo-api-installer: Evolution API + Traefik (SSL) ===${NC}"

# Preguntar subdominio y correo
read -rp "Subdominio para Evolution API (ej: api.tudominio.com): " EVOLUTION_DOMAIN
read -rp "Email para Let's Encrypt (para avisos SSL): " LETSENCRYPT_EMAIL

if [[ -z "${EVOLUTION_DOMAIN}" || -z "${LETSENCRYPT_EMAIL}" ]]; then
  echo -e "${RED}Dominio y email son obligatorios.${NC}"
  exit 1
fi

# Crear .env si no existe
if [[ ! -f .env ]]; then
  if [[ -f .env.example ]]; then
    cp .env.example .env
  else
    echo -e "${RED}No se encontró .env ni .env.example en el directorio actual.${NC}"
    exit 1
  fi
fi

# Sustituir/añadir variables en .env
if grep -q "^EVOLUTION_DOMAIN=" .env; then
  sed -i "s|^EVOLUTION_DOMAIN=.*|EVOLUTION_DOMAIN=${EVOLUTION_DOMAIN}|" .env
else
  echo "EVOLUTION_DOMAIN=${EVOLUTION_DOMAIN}" >> .env
fi

if grep -q "^LETSENCRYPT_EMAIL=" .env; then
  sed -i "s|^LETSENCRYPT_EMAIL=.*|LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}|" .env
else
  echo "LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}" >> .env
fi

# Cargar .env
set -a && source .env && set +a

# Actualizar paquetes e instalar prerequisitos
echo -e "${YELLOW}Actualizando paquetes del sistema...${NC}"
sudo apt update -y
sudo apt install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  netcat-openbsd

# Instalar Docker si no está
if ! command -v docker >/dev/null 2>&1; then
  echo -e "${YELLOW}Instalando Docker...${NC}"
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt update -y
  sudo apt install -y docker-ce docker-ce-cli containerd.io
  sudo systemctl enable --now docker
  sudo usermod -aG docker "$USER" || true
  echo -e "${GREEN}Docker instalado.${NC}"
else
  echo -e "${GREEN}Docker ya está instalado.${NC}"
fi

# Instalar plugin Docker Compose si no está
if ! docker compose version >/dev/null 2>&1; then
  echo -e "${YELLOW}Instalando Docker Compose plugin...${NC}"
  sudo apt install -y docker-compose-plugin
  echo -e "${GREEN}Docker Compose instalado.${NC}"
else
  echo -e "${GREEN}Docker Compose ya está instalado.${NC}"
fi

# Levantar stack con docker compose
echo -e "${YELLOW}Levantando contenedores con docker compose...${NC}"
sudo docker compose pull
sudo docker compose up -d

echo -e "${GREEN}Contenedores levantados. Esperando certificados SSL de Let's Encrypt...${NC}"

# Verificar HTTPS en el dominio
check_https() {
  local attempt=1
  while (( attempt <= CHECK_APP_MAX_ATTEMPTS )); do
    echo -e "${YELLOW}Intento ${attempt}/${CHECK_APP_MAX_ATTEMPTS}: comprobando https://${EVOLUTION_DOMAIN}...${NC}"
    if curl -k --silent --head "https://${EVOLUTION_DOMAIN}" | grep -qiE "200|301|302"; then
      echo -e "${GREEN}¡Instalación completada! Evolution API accesible en: https://${EVOLUTION_DOMAIN}${NC}"
      echo -e "${GREEN}Panel (si aplica): https://${EVOLUTION_DOMAIN}/manager${NC}"
      return 0
    fi
    attempt=$(( attempt + 1 ))
    sleep "${CHECK_APP_DELAY_SECONDS}"
  done
  echo -e "${RED}No se pudo verificar acceso HTTPS a ${EVOLUTION_DOMAIN}.${NC}"
  echo -e "${RED}Revisa que el subdominio apunte a este servidor y que los puertos 80 y 443 estén abiertos (Cloudflare y firewall).${NC}"
  return 1
}

check_https

echo -e "${YELLOW}Si es la primera vez que usas Docker en este usuario, cierra sesión y vuelve a entrar para aplicar el grupo 'docker'.${NC}"
