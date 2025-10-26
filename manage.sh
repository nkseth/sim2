#!/bin/bash

# Simple SimStudio Management Script
set -e

COMPOSE_FILE="docker-compose.prod.yml"

show_help() {
    echo "SimStudio Management Script"
    echo ""
    echo "Usage: ./manage.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start       Start all services"
    echo "  stop        Stop all services"  
    echo "  restart     Restart all services"
    echo "  status      Show service status"
    echo "  logs        Show logs"
    echo "  update      Pull latest images and restart"
    echo "  backup      Backup database"
    echo "  shell       Open shell in simstudio container"
    echo "  help        Show this help message"
}

start_services() {
    echo "Starting services..."
    docker compose -f $COMPOSE_FILE up -d
    echo "✅ Services started"
}

stop_services() {
    echo "Stopping services..."
    docker compose -f $COMPOSE_FILE down
    echo "✅ Services stopped"
}

restart_services() {
    echo "Restarting services..."
    docker compose -f $COMPOSE_FILE restart
    echo "✅ Services restarted"
}

show_status() {
    echo "Service Status:"
    docker compose -f $COMPOSE_FILE ps
}

show_logs() {
    docker compose -f $COMPOSE_FILE logs --tail=50 -f
}

update_services() {
    echo "Updating SimStudio..."
    docker compose -f $COMPOSE_FILE pull
    docker compose -f $COMPOSE_FILE up -d
    echo "✅ Services updated"
}

backup_database() {
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_file="backup_${timestamp}.sql"
    
    echo "Creating database backup..."
    docker compose -f $COMPOSE_FILE exec db pg_dump -U postgres simstudio > $backup_file
    echo "✅ Database backup created: $backup_file"
}

open_shell() {
    echo "Opening shell in SimStudio container..."
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
    backup)
        backup_database
        ;;
    shell)
        open_shell
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac