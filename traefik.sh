#!/bin/bash

# Configuración de colores
YELLOW="\e[33m"
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
RESET="\e[0m"

# Configuración de nodos
MANAGER="root@ip_manager"  # Nodo que será el manager

LOCAL_PATH="./traefik/*"
REMOTE_PATH="~/traefik"

# Desplegar Traefik
deploy_traefik() {
    echo -e "${YELLOW}[*]${RESET} Copiando carpeta traefik a la máquina remota"
    scp -r $LOCAL_PATH $MANAGER:$REMOTE_PATH
    echo -e "${GREEN}[+]${RESET} Carpeta traefik copiada"
    local server_ip=$(ssh $MANAGER "hostname -I | cut -d' ' -f1")
    echo -e "${YELLOW}[*]${RESET} Desplegando Traefik"
    ssh $MANAGER "docker stack deploy -c $REMOTE_PATH/docker-compose.yml traefik"
    echo -e "${GREEN}[+]${RESET} Traefik desplegado. Accede al dashboard en http://$server_ip:8080"
}

# Despliega Traefik y el proyecto de ejemplo
echo -e "${YELLOW}[*]${RESET} Desplegando traefik"
deploy_traefik

echo -e "${GREEN}[+]${RESET} Configuración finalizada"
