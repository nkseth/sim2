#!/bin/bash

# SimStudio Management Script
# Usage: ./manage.sh [command]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

COMPOSE_FILE="docker-compose.prod.yml"

show_help() {
    echo -e "${BLUE}SimStudio Management Script${NC}"
    echo ""
    echo "Usage: ./manage.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start       Start all services"
    echo "  stop        Stop all services"  
    echo "  restart     Restart all services"
    echo "  status      Show service status"
    echo "  logs        Show logs (use -f for follow)"
    echo "  update      Pull latest images and restart"
    echo "  ssl         Setup/renew SSL certificates"
    echo "  backup      Backup database"
    echo "  restore     Restore database from backup"
    echo "  cleanup     Remove unused Docker resources"
    echo "  shell       Open shell in simstudio container"
    echo "  help        Show this help message"
}

start_services() {
    echo -e "${YELLOW}Starting SimStudio services...${NC}"
    docker compose -f $COMPOSE_FILE up -d
    echo -e "${GREEN}✅ Services started${NC}"
}

stop_services() {
    echo -e "${YELLOW}Stopping SimStudio services...${NC}"
    docker compose -f $COMPOSE_FILE down
    echo -e "${GREEN}✅ Services stopped${NC}"
}

restart_services() {
    echo -e "${YELLOW}Restarting SimStudio services...${NC}"
    docker compose -f $COMPOSE_FILE restart
    echo -e "${GREEN}✅ Services restarted${NC}"
}

show_status() {
    echo -e "${BLUE}Service Status:${NC}"
    docker compose -f $COMPOSE_FILE ps
}

show_logs() {
    if [ "$2" = "-f" ]; then
        docker compose -f $COMPOSE_FILE logs -f
    else
        docker compose -f $COMPOSE_FILE logs --tail=100
    fi
}

update_services() {
    echo -e "${YELLOW}Updating SimStudio...${NC}"
    docker compose -f $COMPOSE_FILE pull
    docker compose -f $COMPOSE_FILE up -d
    echo -e "${GREEN}✅ Services updated${NC}"
}

setup_ssl() {
    echo -e "${YELLOW}Setting up SSL certificates...${NC}"
    
    # First, ensure nginx is running with self-signed certs
    docker compose -f $COMPOSE_FILE up -d nginx
    
    # Get Let's Encrypt certificates
    domains=("sim.codingape.in" "realtime.codingape.in" "ollama.codingape.in")
    
    for domain in "${domains[@]}"; do
        echo "Getting certificate for $domain..."
        docker compose -f $COMPOSE_FILE run --rm certbot certonly \
            --webroot \
            --webroot-path=/var/www/html \
            --email admin@codingape.in \
            --agree-tos \
            --no-eff-email \
            --non-interactive \
            -d $domain
    done
    
    # Reload nginx
    docker compose -f $COMPOSE_FILE exec nginx nginx -s reload
    echo -e "${GREEN}✅ SSL certificates configured${NC}"
}

backup_database() {
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_file="backup_${timestamp}.sql"
    
    echo -e "${YELLOW}Creating database backup...${NC}"
    docker compose -f $COMPOSE_FILE exec db pg_dump -U postgres simstudio > $backup_file
    echo -e "${GREEN}✅ Database backup created: $backup_file${NC}"
}

restore_database() {
    if [ -z "$2" ]; then
        echo -e "${RED}Please specify backup file: ./manage.sh restore backup_file.sql${NC}"
        exit 1
    fi
    
    if [ ! -f "$2" ]; then
        echo -e "${RED}Backup file not found: $2${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Restoring database from $2...${NC}"
    docker compose -f $COMPOSE_FILE exec -T db psql -U postgres simstudio < "$2"
    echo -e "${GREEN}✅ Database restored${NC}"
}

cleanup_docker() {
    echo -e "${YELLOW}Cleaning up Docker resources...${NC}"
    docker system prune -f
    docker volume prune -f
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

open_shell() {
    echo -e "${YELLOW}Opening shell in SimStudio container...${NC}"
    docker compose -f $COMPOSE_FILE exec simstudio /bin/sh
}

# Main command handling
case "$1" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$@"
        ;;
    update)
        update_services
        ;;
    ssl)
        setup_ssl
        ;;
    backup)
        backup_database
        ;;
    restore)
        restore_database "$@"
        ;;
    cleanup)
        cleanup_docker
        ;;
    shell)
        open_shell
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac