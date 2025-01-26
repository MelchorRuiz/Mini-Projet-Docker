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

install_gluster() {
    local node="$1"
    echo -e "${YELLOW}[*]${RESET} Instalando GlusterFS en: ${BLUE}$node${RESET}"
    ssh -o StrictHostKeyChecking=no root@$node "sudo apt update && sudo apt install -y glusterfs-server && sudo systemctl start glusterd && sudo systemctl enable glusterd"
    echo -e "${GREEN}[+]${RESET} GlusterFS instalado en: ${BLUE}$node${RESET}"
}

configure_gluster() {
    echo -e "${YELLOW}[*]${RESET} Configurando GlusterFS"
    ssh root@$MANAGER "sudo gluster peer probe ${WORKERS[0]} && sudo gluster peer probe ${WORKERS[1]} && sudo gluster pool list"
    echo -e "${GREEN}[+]${RESET} GlusterFS configurado"
}

make_gluster_volume() {
    echo -e "${YELLOW}[*]${RESET} Creando volumen de GlusterFS"
    ssh root@$MANAGER "sudo gluster volume create gv0 replica 3 transport tcp ${MANAGER}:/data ${WORKERS[0]}:/data ${WORKERS[1]}:/data force"
    ssh root@$MANAGER "sudo gluster volume start gv0"
    echo -e "${GREEN}[+]${RESET} Volumen de GlusterFS creado"
}

mount_gluster() {
    local node="$1"
    echo -e "${YELLOW}[*]${RESET} Montando volumen de GlusterFS en: ${BLUE}$node${RESET}"
    ssh root@$node "sudo apt install -y glusterfs-client"
    ssh root@$node "sudo mkdir -p /mnt/gv0"
    ssh root@$node "sudo mount -t glusterfs ${MANAGER}:/gv0 /mnt/gv0"
    echo -e "${GREEN}[+]${RESET} Volumen de GlusterFS montado en: ${BLUE}$node${RESET}"
    echo -e "${YELLOW}[*]${RESET} Modificando /etc/fstab para montar el volumen de GlusterFS en el arranque"
    ssh root@$node "echo '${MANAGER}:/gv0 /mnt/gv0 glusterfs defaults,_netdev 0 0' | sudo tee -a /etc/fstab"
    echo -e "${GREEN}[+]${RESET} Volumen de GlusterFS montado en el arranque en: ${BLUE}$node${RESET}"
}

active_auto_curation() {
    echo -e "${YELLOW}[*]${RESET} Activando la curación automática de GlusterFS"
    ssh root@$MANAGER "sudo gluster volume set gv0 cluster.self-heal-daemon on"
    echo -e "${GREEN}[+]${RESET} Curación automática activada"
}

echo -e "${YELLOW}[*]${RESET} Configurando GlusterFS"

install_gluster $MANAGER
# Instala GlusterFS en los nodos
for worker in "${WORKERS[@]}"; do
    install_gluster $worker
done

# Configura GlusterFS
configure_gluster

# Crea un volumen de GlusterFS
make_gluster_volume

# Monta el volumen de GlusterFS
mount_gluster $MANAGER
for worker in "${WORKERS[@]}"; do
    mount_gluster $worker
done

active_auto_curation

echo -e "${GREEN}[+]${RESET} Configuración de GlusterFS finalizada"