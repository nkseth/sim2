#!/bin/bash

# 🚀 Complete Linux Deployment Script for SimStudio
# This script will deploy SimStudio on Linux with proper domain configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 SimStudio Linux Deployment Script${NC}"
echo -e "${BLUE}====================================${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to generate random secret
generate_secret() {
    openssl rand -hex 32
}

# Check system requirements
echo -e "${YELLOW}📋 Checking system requirements...${NC}"

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}❌ This script is designed for Linux systems${NC}"
    exit 1
fi

# Check Docker
if ! command_exists docker; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo "Please install Docker first:"
    echo "curl -fsSL https://get.docker.com | sh"
    echo "sudo usermod -aG docker \$USER"
    echo "newgrp docker"
    exit 1
fi

# Check Docker Compose
if ! docker compose version >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker Compose is not available${NC}"
    echo "Please install Docker Compose plugin:"
    echo "sudo apt update && sudo apt install docker-compose-plugin"
    exit 1
fi

# Check if user is in docker group
if ! groups | grep -q docker; then
    echo -e "${YELLOW}⚠️  Adding user to docker group...${NC}"
    sudo usermod -aG docker $USER
    echo -e "${YELLOW}Please log out and log back in, then run this script again${NC}"
    exit 1
fi

# Check required ports
echo -e "${YELLOW}🔍 Checking port availability...${NC}"
for port in 80 443 3000 3002 5432; do
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo -e "${YELLOW}⚠️  Port $port is already in use${NC}"
        if [ "$port" = "80" ] || [ "$port" = "443" ]; then
            echo -e "${RED}Ports 80 and 443 must be available for web access${NC}"
            echo "Please stop any web servers running on these ports"
            exit 1
        fi
    else
        echo -e "${GREEN}✅ Port $port is available${NC}"
    fi
done

# Check firewall
echo -e "${YELLOW}🔥 Checking firewall settings...${NC}"
if command_exists ufw; then
    if ufw status | grep -q "Status: active"; then
        echo -e "${YELLOW}Configuring UFW firewall...${NC}"
        sudo ufw allow 22/tcp  # SSH
        sudo ufw allow 80/tcp  # HTTP
        sudo ufw allow 443/tcp # HTTPS
        echo -e "${GREEN}✅ Firewall configured${NC}"
    fi
elif command_exists firewall-cmd; then
    echo -e "${YELLOW}Configuring firewalld...${NC}"
    sudo firewall-cmd --permanent --add-service=ssh
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-service=https
    sudo firewall-cmd --reload
    echo -e "${GREEN}✅ Firewall configured${NC}"
fi

# Create necessary directories
echo -e "${YELLOW}📁 Creating directories...${NC}"
mkdir -p nginx/ssl/{sim.codingape.in,realtime.codingape.in,ollama.codingape.in}
mkdir -p logs backups

# Generate SSL certificates for initial setup
echo -e "${YELLOW}🔐 Generating self-signed SSL certificates...${NC}"
domains=("sim.codingape.in" "realtime.codingape.in" "ollama.codingape.in")

for domain in "${domains[@]}"; do
    if [ ! -f "nginx/ssl/$domain/fullchain.pem" ]; then
        echo "Generating certificate for $domain..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout nginx/ssl/$domain/privkey.pem \
            -out nginx/ssl/$domain/fullchain.pem \
            -subj "/C=US/ST=State/L=City/O=SimStudio/CN=$domain" \
            -addext "subjectAltName=DNS:$domain" 2>/dev/null
        echo -e "${GREEN}✅ Certificate created for $domain${NC}"
    else
        echo -e "${GREEN}✅ Certificate already exists for $domain${NC}"
    fi
done

# Create environment file
echo -e "${YELLOW}📝 Creating environment configuration...${NC}"
if [ ! -f ".env" ]; then
    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "YOUR_SERVER_IP")
    
    # Generate secrets
    BETTER_AUTH_SECRET=$(generate_secret)
    ENCRYPTION_KEY=$(generate_secret)
    INTERNAL_API_SECRET=$(generate_secret)
    
    cat > .env << EOF
# Generated on $(date)
# Server IP: $SERVER_IP

# Database Configuration
DATABASE_URL="postgresql://postgres:postgres@db:5432/simstudio"
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=simstudio
POSTGRES_PORT=5432

# Application URLs
BETTER_AUTH_URL=https://sim.codingape.in
NEXT_PUBLIC_APP_URL=https://sim.codingape.in

# Security Secrets (Generated automatically)
BETTER_AUTH_SECRET=$BETTER_AUTH_SECRET
ENCRYPTION_KEY=$ENCRYPTION_KEY
INTERNAL_API_SECRET=$INTERNAL_API_SECRET

# Service URLs
OLLAMA_URL=https://ollama.codingape.in
SOCKET_SERVER_URL=https://realtime.codingape.in
NEXT_PUBLIC_SOCKET_URL=https://realtime.codingape.in

# Optional APIs (empty to avoid warnings)
COPILOT_API_KEY=
SIM_AGENT_API_URL=

# Email (optional)
# RESEND_API_KEY=your_resend_api_key_here
EOF
    
    echo -e "${GREEN}✅ Environment file created with generated secrets${NC}"
else
    echo -e "${GREEN}✅ Environment file already exists${NC}"
fi

# Create simple nginx config for initial deployment
echo -e "${YELLOW}🌐 Creating Nginx configuration...${NC}"
cat > nginx/simple-nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    
    # Upstream
    upstream simstudio {
        server simstudio:3000;
    }
    
    upstream realtime {
        server realtime:3002;
    }
    
    # Main application
    server {
        listen 80;
        server_name sim.codingape.in _;
        
        client_max_body_size 100M;
        
        location / {
            proxy_pass http://simstudio;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            proxy_read_timeout 86400;
        }
        
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://simstudio;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
    
    # Realtime service
    server {
        listen 80;
        server_name realtime.codingape.in;
        
        location / {
            proxy_pass http://realtime;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }
    }
}
EOF

# Pull images
echo -e "${YELLOW}📦 Pulling Docker images...${NC}"
docker compose -f docker-compose.prod.yml pull

# Start services
echo -e "${YELLOW}🚀 Starting services...${NC}"
docker compose -f docker-compose.prod.yml up -d

# Wait for services
echo -e "${YELLOW}⏳ Waiting for services to start...${NC}"
sleep 30

# Health check
echo -e "${YELLOW}🏥 Checking service health...${NC}"
services=("nginx" "simstudio" "realtime" "db")
all_healthy=true

for service in "${services[@]}"; do
    if docker compose -f docker-compose.prod.yml ps | grep -q "$service.*Up"; then
        echo -e "${GREEN}✅ $service is running${NC}"
    else
        echo -e "${RED}❌ $service is not running${NC}"
        all_healthy=false
    fi
done

# Show logs for failed services
if [ "$all_healthy" = false ]; then
    echo -e "${YELLOW}📋 Showing logs for troubleshooting:${NC}"
    docker compose -f docker-compose.prod.yml logs --tail=20
fi

# Test connectivity
echo -e "${YELLOW}🔗 Testing connectivity...${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✅ Local HTTP access working${NC}"
else
    echo -e "${RED}❌ Local HTTP access failed${NC}"
fi

# Get server information
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "Unable to detect")

# Final information
echo -e "\n${GREEN}🎉 Deployment completed!${NC}"
echo -e "\n${BLUE}📋 Deployment Summary:${NC}"
echo -e "Server IP: ${GREEN}$SERVER_IP${NC}"
echo -e "Local access: ${GREEN}http://localhost${NC}"
echo -e "Domain access: ${GREEN}https://sim.codingape.in${NC} (after DNS propagation)"
echo -e "\n${BLUE}📋 DNS Configuration Required:${NC}"
echo "Add these A records in your domain DNS:"
echo -e "${YELLOW}sim.codingape.in      A    $SERVER_IP${NC}"
echo -e "${YELLOW}realtime.codingape.in A    $SERVER_IP${NC}"
echo -e "${YELLOW}ollama.codingape.in   A    $SERVER_IP${NC}"
echo -e "\n${BLUE}📋 Management Commands:${NC}"
echo -e "${YELLOW}./manage.sh status${NC}    - Check service status"
echo -e "${YELLOW}./manage.sh logs -f${NC}   - Follow logs"
echo -e "${YELLOW}./manage.sh restart${NC}   - Restart services"
echo -e "${YELLOW}./manage.sh ssl${NC}       - Setup SSL certificates (after DNS)"
echo -e "${YELLOW}./manage.sh backup${NC}    - Backup database"

if [ "$all_healthy" = true ]; then
    echo -e "\n${GREEN}✅ All services are running successfully!${NC}"
    echo -e "You can now configure your DNS records and access your application."
else
    echo -e "\n${RED}⚠️  Some services failed to start. Check logs above.${NC}"
    echo -e "Run: ${YELLOW}./manage.sh logs${NC} for more details"
fi

echo -e "\n${BLUE}🔧 Troubleshooting:${NC}"
echo -e "If you encounter issues:"
echo -e "1. Check logs: ${YELLOW}docker compose -f docker-compose.prod.yml logs${NC}"
echo -e "2. Check ports: ${YELLOW}sudo netstat -tlnp | grep -E ':(80|443|3000|3002)'${NC}"
echo -e "3. Test DNS: ${YELLOW}nslookup sim.codingape.in${NC}"
echo -e "4. Check firewall: ${YELLOW}sudo ufw status${NC}"

echo -e "\n${GREEN}Happy coding! 🚀${NC}"