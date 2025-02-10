#!/bin/bash

# -----------------------------------------------------
# --------------  Initial Configuration  --------------
# -----------------------------------------------------

# Description:
# This script sets up a Docker Swarm cluster with GlusterFS on three nodes.
# The first node will act as the manager and the other two as workers.
# Then, services will be deployed with Docker stack.

# Color configuration
YELLOW="\e[33m"
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
RESET="\e[0m"

echo -e "${YELLOW}[*]${RESET} Docker Swarm Project"

# Node configuration
USER=$1
MANAGER=$2  # Node that will be the manager
WORKERS=($3 $4)  # Nodes that will be workers

# Check if the necessary arguments are provided
if [ -z "$MANAGER" ] || [ -z "$WORKERS" ]; then
    echo -e "${RED}[!]${RESET} Usage: $0 <user> <manager> <worker1> <worker2>"
    exit 1
fi

# -----------------------------------------------------
# --------  Docker Swarm Configuration  ------------
# -----------------------------------------------------

echo -e "${YELLOW}[*]${RESET} Configuring Docker on the servers $MANAGER and ${WORKERS[@]}"

DOCKER_INSTALL_COMMANDS="
    sudo apt update &&
    sudo apt install -y docker.io &&
    sudo systemctl start docker &&
    sudo systemctl enable docker &&
    sudo usermod -aG docker \$USER &&
    echo 'Docker installed and configured'
"

# Function to install Docker
install_docker() {
    local node="$1"
    echo -e "${YELLOW}[*]${RESET} Installing Docker on: ${BLUE}$node${RESET}"
    ssh $USER@$node "$DOCKER_INSTALL_COMMANDS"
    echo -e "${GREEN}[+]${RESET} Docker installed on: ${BLUE}$node${RESET}"
}

# Initialize Docker Swarm on the manager node
initialize_swarm() {
    echo -e "${YELLOW}[*]${RESET} Checking if Docker Swarm is already initialized on the manager"

    # Check if the manager is already part of a swarm
    local swarm_status=$(ssh $USER@$MANAGER "docker info --format '{{.Swarm.LocalNodeState}}'")
    local manager_ip=$(ssh $USER@$MANAGER "hostname -I | awk '{print \$1}'")

    if [ "$swarm_status" == "active" ]; then
        echo -e "${GREEN}[+]${RESET} Docker Swarm is already initialized on the manager"
    else
        echo -e "${YELLOW}[*]${RESET} Initializing Docker Swarm on the manager"
        ssh $USER@$MANAGER "docker swarm init --advertise-addr $manager_ip"

        echo -e "${GREEN}[+]${RESET} Docker Swarm initialized on the manager"
    fi
}

# Configure the workers to join the Swarm
join_swarm_workers() {
    for worker in "${WORKERS[@]}"; do
        echo -e "${YELLOW}[*]${RESET} Checking if the worker is already joined to the Swarm: ${BLUE}$worker${RESET}"

        # Check if the worker is already in a swarm
        local swarm_status=$(ssh $USER@$worker "docker info --format '{{.Swarm.LocalNodeState}}'")

        if [ "$swarm_status" == "active" ]; then
            echo -e "${GREEN}[+]${RESET} The worker is already joined to the Swarm: ${BLUE}$worker${RESET}"
        else
            echo -e "${YELLOW}[*]${RESET} Joining worker to the Swarm: ${BLUE}$worker${RESET}"
            local join_token=$(ssh $USER@$MANAGER "docker swarm join-token worker -q")
            local manager_ip=$(ssh $USER@$MANAGER "hostname -I | awk '{print \$1}'")
            ssh $USER@$worker "sudo docker swarm join --token $join_token $manager_ip:2377"
            echo -e "${GREEN}[+]${RESET} Worker joined to the Swarm: ${BLUE}$worker${RESET}"
        fi
    done
}

# Execute Docker installation on all nodes
echo -e "${YELLOW}[*]${RESET} Configuring Docker Swarm"
install_docker "$MANAGER"
for worker in "${WORKERS[@]}"; do
    install_docker "$worker"
done

# Initialize the Swarm and join the workers
echo -e "${YELLOW}[*]${RESET} Initializing Docker Swarm"
initialize_swarm
join_swarm_workers

echo -e "${GREEN}[+]${RESET} Configuration completed"

# -----------------------------------------------------
# --------  GlusterFS Configuration  ---------------
# -----------------------------------------------------

echo -e "${YELLOW}[*]${RESET} Configuring GlusterFS on the servers"

install_gluster() {
    local node="$1"
    echo -e "${YELLOW}[*]${RESET} Installing GlusterFS on: ${BLUE}$node${RESET}"
    ssh $USER@$node "sudo apt update && sudo apt install -y glusterfs-server && sudo systemctl start glusterd && sudo systemctl enable glusterd"
    echo -e "${GREEN}[+]${RESET} GlusterFS installed on: ${BLUE}$node${RESET}"
}

configure_gluster() {
    echo -e "${YELLOW}[*]${RESET} Configuring GlusterFS"
    if ssh $USER@$MANAGER "sudo gluster peer status | grep -q 'Number of Peers: 2'"; then
        echo -e "${GREEN}[+]${RESET} GlusterFS is already configured"
    else
        local worker1_ip=$(ssh $USER@${WORKERS[0]} "hostname -I | cut -d' ' -f1")
        local worker2_ip=$(ssh $USER@${WORKERS[1]} "hostname -I | cut -d' ' -f1")
        ssh $USER@$MANAGER "sudo gluster peer probe $worker1_ip && sudo gluster peer probe $worker2_ip && sudo gluster pool list"
        echo -e "${GREEN}[+]${RESET} GlusterFS configured"
    fi
}

make_gluster_volume() {
    local volume_name="$1"
    local brick_dir="/data/$volume_name"
    echo -e "${YELLOW}[*]${RESET} Creating GlusterFS volume: ${BLUE}$volume_name${RESET}"
    if ssh $USER@$MANAGER "sudo gluster volume info $volume_name | grep -q 'Status: Started'"; then
        echo -e "${GREEN}[+]${RESET} GlusterFS volume ${BLUE}$volume_name${RESET} is already created and running"
    else
        ssh $USER@$MANAGER "sudo mkdir -p $brick_dir"
        for worker in "${WORKERS[@]}"; do
            ssh $USER@$worker "sudo mkdir -p $brick_dir"
        done
        local manager_ip=$(ssh $USER@$MANAGER "hostname -I | cut -d' ' -f1")
        local worker1_ip=$(ssh $USER@${WORKERS[0]} "hostname -I | cut -d' ' -f1")
        local worker2_ip=$(ssh $USER@${WORKERS[1]} "hostname -I | cut -d' ' -f1")
        ssh $USER@$MANAGER "sudo gluster volume create $volume_name replica 3 transport tcp ${manager_ip}:${brick_dir} ${worker1_ip}:${brick_dir} ${worker2_ip}:${brick_dir} force"
        ssh $USER@$MANAGER "sudo gluster volume start $volume_name"
        echo -e "${GREEN}[+]${RESET} GlusterFS volume ${BLUE}$volume_name${RESET} created"
    fi
}

mount_gluster() {
    local node="$1"
    local volume_name="$2"
    echo -e "${YELLOW}[*]${RESET} Mounting GlusterFS volume ${BLUE}$volume_name${RESET} on: ${BLUE}$node${RESET}"
    if ssh $USER@$node "mount | grep -q '/mnt/$volume_name'"; then
        echo -e "${GREEN}[+]${RESET} GlusterFS volume ${BLUE}$volume_name${RESET} is already mounted on: ${BLUE}$node${RESET}"
    else
        ssh $USER@$node "sudo apt install -y glusterfs-client"
        ssh $USER@$node "sudo mkdir -p /mnt/$volume_name"
        local manager_ip=$(ssh $USER@$MANAGER "hostname -I | cut -d' ' -f1")
        ssh $USER@$node "sudo mount -t glusterfs ${manager_ip}:/$volume_name /mnt/$volume_name"
        echo -e "${GREEN}[+]${RESET} GlusterFS volume ${BLUE}$volume_name${RESET} mounted on: ${BLUE}$node${RESET}"
        echo -e "${YELLOW}[*]${RESET} Modifying /etc/fstab to mount GlusterFS volume ${BLUE}$volume_name${RESET} on boot"
        ssh $USER@$node "echo '${MANAGER}:/$volume_name /mnt/$volume_name glusterfs defaults,_netdev 0 0' | sudo tee -a /etc/fstab"
        echo -e "${GREEN}[+]${RESET} GlusterFS volume ${BLUE}$volume_name${RESET} mounted on boot on: ${BLUE}$node${RESET}"
    fi
}

active_auto_curation() {
    local volume_name="$1"
    echo -e "${YELLOW}[*]${RESET} Activating GlusterFS auto-heal for volume: ${BLUE}$volume_name${RESET}"
    if ssh $USER@$MANAGER "sudo gluster volume get $volume_name cluster.self-heal-daemon | grep -q 'on'"; then
        echo -e "${GREEN}[+]${RESET} Auto-heal is already activated for volume: ${BLUE}$volume_name${RESET}"
    else
        ssh $USER@$MANAGER "sudo gluster volume set $volume_name cluster.self-heal-daemon on"
        echo -e "${GREEN}[+]${RESET} Auto-heal activated for volume: ${BLUE}$volume_name${RESET}"
    fi
}

echo -e "${YELLOW}[*]${RESET} Configuring GlusterFS"

install_gluster $MANAGER
# Install GlusterFS on the nodes
for worker in "${WORKERS[@]}"; do
    install_gluster $worker
done

# Configure GlusterFS
configure_gluster

# Create and mount GlusterFS volumes
VOLUMES=("gv0" "gv1")
for volume in "${VOLUMES[@]}"; do
    make_gluster_volume $volume
    mount_gluster $MANAGER $volume
    for worker in "${WORKERS[@]}"; do
        mount_gluster $worker $volume
    done
    active_auto_curation $volume
done

echo -e "${GREEN}[+]${RESET} GlusterFS configuration completed"

# -----------------------------------------------------
# -----  Deploy services with Docker stack  ----
# -----------------------------------------------------

echo -e "${YELLOW}[*]${RESET} Deploying services with Docker stack"

echo -e "${YELLOW}[*]${RESET} Copying files to the remote machine"
scp docker-compose.yml $USER@$MANAGER:~
scp -r traefik.yml $USER@$MANAGER:~
scp -r dynamic.yml $USER@$MANAGER:~
echo -e "${GREEN}[+]${RESET} Files copied"

server_ip=$(ssh $USER@$MANAGER "hostname -I | cut -d' ' -f1")

echo -e "${YELLOW}[*]${RESET} Deploying services"
ssh $USER@$MANAGER "docker stack deploy -c ~/docker-compose.yml project"
echo -e "${GREEN}[+]${RESET} Services deployed. Access the dashboard at http://$server_ip:8080"

echo -e "${GREEN}[+]${RESET} Configuration completed"

echo -e "${YELLOW}[+]${RESET} Finished"