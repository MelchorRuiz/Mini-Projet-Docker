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

LOCAL_PATH="./web-simple"
REMOTE_PATH="/mnt/gv0/web-simple"

# Desplegar web simple
deploy_web_simple() {
    echo -e "${YELLOW}[*]${RESET} Copiando carpeta web-simple a la máquina remota"
    scp -r $LOCAL_PATH $MANAGER:/mnt/gv0/
    echo -e "${GREEN}[+]${RESET} compose web-simple copiado"
    local server_ip=$(ssh $MANAGER "hostname -I | cut -d' ' -f1")
    echo -e "${YELLOW}[*]${RESET} Desplegando web simple"
    ssh $MANAGER "docker stack deploy -c $REMOTE_PATH/docker-compose.yml web-simple"
    echo -e "${GREEN}[+]${RESET} web-simple desplegada. Accede a la web en http://$server_ip/web-simple"
}

# Despliega Web Simple
echo -e "${YELLOW}[*]${RESET} Desplegando web-simple"
deploy_web_simple

echo -e "${GREEN}[+]${RESET} Despliegue finalizado"
