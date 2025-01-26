#!/bin/bash

# Configuración de colores
YELLOW="\e[33m"
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
RESET="\e[0m"

echo -e "${YELLOW}[*]${RESET} Proyecto Docker Swarm"

echo -e "${YELLOW}[*]${RESET} Configurar docker en los servidores"
./configurate_docker.sh

echo -e "${YELLOW}[*]${RESET} Configurar gluster en los servidores"
./configurate_gluster.sh

echo -e "${YELLOW}[*]${RESET} Configurar traefik en los servidores"
./traefik.sh

echo -e "${YELLOW}[*]${RESET} Crear una pagina web simple"
./web-simple.sh

echo -e "${YELLOW}[+]${RESET} Finalizado"