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
MANAGER="root@164.92.84.181"  # Nodo que será el manager
WORKERS=("root@24.144.82.202" "root@24.144.92.34")  # Nodos que serán workers

LOCAL_YML_PATH="./"
REMOTE_YML_PATH="/tmp"

echo -e "${YELLOW}[*]${RESET} Configurar los servidores"
./init_servers.sh

echo -e "${YELLOW}[*]${RESET} Configurar los servicios"
./init_services.sh
