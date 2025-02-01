#!/bin/bash

# -----------------------------------------------------
# --------------  Configuración inicial  --------------
# -----------------------------------------------------

# Descripción:
# Este script configura un clúster de Docker Swarm con GlusterFS en tres nodos.
# El primer nodo actuará como manager y los otros dos como workers.
# Luego, se desplegarán servicios con Docker stack.

# Configuración de colores
YELLOW="\e[33m"
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
RESET="\e[0m"

echo -e "${YELLOW}[*]${RESET} Proyecto Docker Swarm"

# Configuración de nodos
MANAGER=$1  # Nodo que será el manager
WORKERS=($2 $3)  # Nodos que serán workers

# Verificar si se proporcionaron los argumentos necesarios
if [ -z "$MANAGER" ] || [ -z "$WORKERS" ]; then
    echo -e "${RED}[!]${RESET} Uso: $0 <manager_ip> <worker1_ip> <worker2_ip>"
    exit 1
fi

# -----------------------------------------------------
# --------  Configuración de Docker Swarm  ------------
# -----------------------------------------------------

echo -e "${YELLOW}[*]${RESET} Configurar docker en los servidores $MANAGER y ${WORKERS[@]}"

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
    ssh root@$node "$DOCKER_INSTALL_COMMANDS"
    echo -e "${GREEN}[+]${RESET} Docker instalado en: ${BLUE}$node${RESET}"
}

# Inicia Docker Swarm en el nodo manager
initialize_swarm() {
    echo -e "${YELLOW}[*]${RESET} Comprobando si Docker Swarm ya está inicializado en el manager"

    # Verificar si el manager ya es parte de un swarm
    SWARM_STATUS=$(ssh root@$MANAGER "docker info --format '{{.Swarm.LocalNodeState}}'")
    MANAGER_IP=$(ssh root@$MANAGER "hostname -I | awk '{print \$1}'")

    if [ "$SWARM_STATUS" == "active" ]; then
        echo -e "${GREEN}[+]${RESET} Docker Swarm ya está inicializado en el manager"
    else
        echo -e "${YELLOW}[*]${RESET} Inicializando Docker Swarm en el manager"
        ssh root@$MANAGER "docker swarm init --advertise-addr $MANAGER_IP"

        # Extrae el token de unión para los workers
        JOIN_TOKEN=$(ssh root@$MANAGER "docker swarm join-token worker -q")
        echo -e "${GREEN}[+]${RESET} Docker Swarm inicializado en el manager"
    fi
}

# Configura los workers para unirse al Swarm
join_swarm_workers() {
    for worker in "${WORKERS[@]}"; do
        echo -e "${YELLOW}[*]${RESET} Comprobando si el worker ya está unido al Swarm: ${BLUE}$worker${RESET}"

        # Verificar si el worker ya está en un swarm
        SWARM_STATUS=$(ssh root@$worker "docker info --format '{{.Swarm.LocalNodeState}}'")

        if [ "$SWARM_STATUS" == "active" ]; then
            echo -e "${GREEN}[+]${RESET} El worker ya está unido al Swarm: ${BLUE}$worker${RESET}"
        else
            echo -e "${YELLOW}[*]${RESET} Uniendo worker al Swarm: ${BLUE}$worker${RESET}"
            ssh root@$worker "sudo docker swarm join --token $JOIN_TOKEN $MANAGER_IP:2377"
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

# -----------------------------------------------------
# --------  Configuración de GlusterFS  ---------------
# -----------------------------------------------------

echo -e "${YELLOW}[*]${RESET} Configurar gluster en los servidores"

install_gluster() {
    local node="$1"
    echo -e "${YELLOW}[*]${RESET} Instalando GlusterFS en: ${BLUE}$node${RESET}"
    ssh root@$node "sudo apt update && sudo apt install -y glusterfs-server && sudo systemctl start glusterd && sudo systemctl enable glusterd"
    echo -e "${GREEN}[+]${RESET} GlusterFS instalado en: ${BLUE}$node${RESET}"
}

configure_gluster() {
    echo -e "${YELLOW}[*]${RESET} Configurando GlusterFS"
    if ssh root@$MANAGER "sudo gluster peer status | grep -q 'Number of Peers: 2'"; then
        echo -e "${GREEN}[+]${RESET} GlusterFS ya está configurado"
    else
        ssh root@$MANAGER "sudo gluster peer probe ${WORKERS[0]} && sudo gluster peer probe ${WORKERS[1]} && sudo gluster pool list"
        echo -e "${GREEN}[+]${RESET} GlusterFS configurado"
    fi
}

make_gluster_volume() {
    local volume_name="$1"
    echo -e "${YELLOW}[*]${RESET} Creando volumen de GlusterFS: ${BLUE}$volume_name${RESET}"
    if ssh root@$MANAGER "sudo gluster volume info $volume_name | grep -q 'Status: Started'"; then
        echo -e "${GREEN}[+]${RESET} Volumen de GlusterFS ${BLUE}$volume_name${RESET} ya está creado y en funcionamiento"
    else
        ssh root@$MANAGER "sudo gluster volume create $volume_name replica 3 transport tcp ${MANAGER}:/data ${WORKERS[0]}:/data ${WORKERS[1]}:/data force"
        ssh root@$MANAGER "sudo gluster volume start $volume_name"
        echo -e "${GREEN}[+]${RESET} Volumen de GlusterFS ${BLUE}$volume_name${RESET} creado"
    fi
}

mount_gluster() {
    local node="$1"
    local volume_name="$2"
    echo -e "${YELLOW}[*]${RESET} Montando volumen de GlusterFS ${BLUE}$volume_name${RESET} en: ${BLUE}$node${RESET}"
    if ssh root@$node "mount | grep -q '/mnt/$volume_name'"; then
        echo -e "${GREEN}[+]${RESET} Volumen de GlusterFS ${BLUE}$volume_name${RESET} ya está montado en: ${BLUE}$node${RESET}"
    else
        ssh root@$node "sudo apt install -y glusterfs-client"
        ssh root@$node "sudo mkdir -p /mnt/$volume_name"
        ssh root@$node "sudo mount -t glusterfs ${MANAGER}:/$volume_name /mnt/$volume_name"
        echo -e "${GREEN}[+]${RESET} Volumen de GlusterFS ${BLUE}$volume_name${RESET} montado en: ${BLUE}$node${RESET}"
        echo -e "${YELLOW}[*]${RESET} Modificando /etc/fstab para montar el volumen de GlusterFS ${BLUE}$volume_name${RESET} en el arranque"
        ssh root@$node "echo '${MANAGER}:/$volume_name /mnt/$volume_name glusterfs defaults,_netdev 0 0' | sudo tee -a /etc/fstab"
        echo -e "${GREEN}[+]${RESET} Volumen de GlusterFS ${BLUE}$volume_name${RESET} montado en el arranque en: ${BLUE}$node${RESET}"
    fi
}

active_auto_curation() {
    local volume_name="$1"
    echo -e "${YELLOW}[*]${RESET} Activando la curación automática de GlusterFS para el volumen: ${BLUE}$volume_name${RESET}"
    if ssh root@$MANAGER "sudo gluster volume get $volume_name cluster.self-heal-daemon | grep -q 'on'"; then
        echo -e "${GREEN}[+]${RESET} Curación automática ya está activada para el volumen: ${BLUE}$volume_name${RESET}"
    else
        ssh root@$MANAGER "sudo gluster volume set $volume_name cluster.self-heal-daemon on"
        echo -e "${GREEN}[+]${RESET} Curación automática activada para el volumen: ${BLUE}$volume_name${RESET}"
    fi
}

echo -e "${YELLOW}[*]${RESET} Configurando GlusterFS"

install_gluster $MANAGER
# Instala GlusterFS en los nodos
for worker in "${WORKERS[@]}"; do
    install_gluster $worker
done

# Configura GlusterFS
configure_gluster

VOLUMES = ("gv0")
for volume in "${VOLUMES[@]}"; do
    make_gluster_volume $volume
    mount_gluster $MANAGER $volume
    for worker in "${WORKERS[@]}"; do
        mount_gluster $worker $volume
    done
    active_auto_curation $volume
done

active_auto_curation

echo -e "${GREEN}[+]${RESET} Configuración de GlusterFS finalizada"

# -----------------------------------------------------
# -----  Despliegue de servicios con Docker stack  ----
# -----------------------------------------------------

echo -e "${YELLOW}[*]${RESET} Desplegando servicios con Docker stack"

echo -e "${YELLOW}[*]${RESET} Copiando archivos a la máquina remota"
scp docker-compose.yml root@$MANAGER:~
scp -r traefik.yml root@$MANAGER:~
echo -e "${GREEN}[+]${RESET} Archivos copiados"

server_ip=$(ssh root@$MANAGER "hostname -I | cut -d' ' -f1")

echo -e "${YELLOW}[*]${RESET} Desplegando servicios"
ssh root@$MANAGER "docker stack deploy -c ~/docker-compose.yml project"
echo -e "${GREEN}[+]${RESET} Servicios desplegados. Accede al dashboard en http://$server_ip:8080"

echo -e "${GREEN}[+]${RESET} Configuración finalizada"

echo -e "${YELLOW}[+]${RESET} Finalizado"