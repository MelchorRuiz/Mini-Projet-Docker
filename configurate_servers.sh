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
WORKERS=("root@ip_worker1" "root@ip_worker2")  # Nodos que serán workers

# Comandos para instalación de Docker
DOCKER_INSTALL_COMMANDS="
    sudo apt update &&
    sudo apt install -y docker.io &&
    sudo systemctl start docker &&
    sudo systemctl enable docker &&
    sudo usermod -aG docker \$USER &&
    echo 'Docker instalado y configurado'
"

# Función para instalar Docker
install_docker() {
    local node="$1"
    echo -e "${YELLOW}[*]${RESET} Instalando Docker en: ${BLUE}$node${RESET}"
    ssh -o StrictHostKeyChecking=no $node "$DOCKER_INSTALL_COMMANDS"
    echo -e "${GREEN}[+]${RESET} Docker instalado en: ${BLUE}$node${RESET}"
}

# Inicia Docker Swarm en el nodo manager
initialize_swarm() {
    echo -e "${YELLOW}[*]${RESET} Comprobando si Docker Swarm ya está inicializado en el manager"

    # Verificar si el manager ya es parte de un swarm
    SWARM_STATUS=$(ssh -o StrictHostKeyChecking=no $MANAGER "docker info --format '{{.Swarm.LocalNodeState}}'")
    MANAGER_IP=$(ssh $MANAGER "hostname -I | awk '{print \$1}'")

    if [ "$SWARM_STATUS" == "active" ]; then
        echo -e "${GREEN}[+]${RESET} Docker Swarm ya está inicializado en el manager"
    else
        echo -e "${YELLOW}[*]${RESET} Inicializando Docker Swarm en el manager"
        ssh $MANAGER "docker swarm init --advertise-addr $MANAGER_IP"

        # Extrae el token de unión para los workers
        JOIN_TOKEN=$(ssh $MANAGER "docker swarm join-token worker -q")
        echo -e "${GREEN}[+]${RESET} Docker Swarm inicializado en el manager"

        echo -e "${YELLOW}[*]${RESET} Creando red overlay para el Swarm"
        ssh $MANAGER "docker network create --driver=overlay traefik-public"
        echo -e "${GREEN}[+]${RESET} Red overlay creada"
    fi
}

# Configura los workers para unirse al Swarm
join_swarm_workers() {
    for worker in "${WORKERS[@]}"; do
        echo -e "${YELLOW}[*]${RESET} Comprobando si el worker ya está unido al Swarm: ${BLUE}$worker${RESET}"

        # Verificar si el worker ya está en un swarm
        SWARM_STATUS=$(ssh -o StrictHostKeyChecking=no $worker "docker info --format '{{.Swarm.LocalNodeState}}'")

        if [ "$SWARM_STATUS" == "active" ]; then
            echo -e "${GREEN}[+]${RESET} El worker ya está unido al Swarm: ${BLUE}$worker${RESET}"
        else
            echo -e "${YELLOW}[*]${RESET} Uniendo worker al Swarm: ${BLUE}$worker${RESET}"
            ssh -o StrictHostKeyChecking=no $worker "sudo docker swarm join --token $JOIN_TOKEN $MANAGER_IP:2377"
            echo -e "${GREEN}[+]${RESET} Worker unido al Swarm: ${BLUE}$worker${RESET}"
        fi
    done
}

# Ejecuta la instalación de Docker en todos los nodos
echo -e "${YELLOW}[*]${RESET} Configurando Docker Swarm"
install_docker "$MANAGER"
for worker in "${WORKERS[@]}"; do
    install_docker "$worker"
done

# Inicializa el Swarm y une los workers
echo -e "${YELLOW}[*]${RESET} Inicializando Docker Swarm"
initialize_swarm
join_swarm_workers

echo -e "${GREEN}[+]${RESET} Configuración finalizada"