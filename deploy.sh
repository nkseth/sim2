#!/bin/bash

set -e

echo "🚀 Starting SimStudio deployment on sim.codingape.in"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker and Docker Compose are installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo -e "${RED}Docker Compose is not available. Please install Docker Compose plugin.${NC}"
    exit 1
fi

# Create necessary directories
echo -e "${YELLOW}Creating necessary directories...${NC}"
mkdir -p nginx/ssl/sim.codingape.in
mkdir -p nginx/ssl/realtime.codingape.in
mkdir -p nginx/ssl/ollama.codingape.in

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Creating .env file from .env.example...${NC}"
    if [ -f "apps/sim/.env.example" ]; then
        cp apps/sim/.env.example .env
        echo -e "${RED}⚠️  IMPORTANT: Please edit .env file and update the following:${NC}"
        echo "   - BETTER_AUTH_SECRET (generate with: openssl rand -hex 32)"
        echo "   - ENCRYPTION_KEY (generate with: openssl rand -hex 32)"
        echo "   - INTERNAL_API_SECRET (generate with: openssl rand -hex 32)"
        echo "   - DATABASE_URL (if different from default)"
        echo "   - Add your API keys if needed"
        echo ""
        read -p "Press Enter after updating .env file to continue..."
    else
        echo -e "${RED}.env.example not found. Please create .env file manually.${NC}"
        exit 1
    fi
fi

# Generate self-signed certificates for initial setup
echo -e "${YELLOW}Generating self-signed SSL certificates for initial setup...${NC}"
domains=("sim.codingape.in" "realtime.codingape.in" "ollama.codingape.in")

for domain in "${domains[@]}"; do
    if [ ! -f "nginx/ssl/$domain/fullchain.pem" ]; then
        echo "Generating certificate for $domain..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout nginx/ssl/$domain/privkey.pem \
            -out nginx/ssl/$domain/fullchain.pem \
            -subj "/C=US/ST=State/L=City/O=SimStudio/CN=$domain"
    fi
done

# Pull latest images
echo -e "${YELLOW}Pulling latest Docker images...${NC}"
docker compose -f docker-compose.prod.yml pull

# Start the services
echo -e "${YELLOW}Starting services...${NC}"
docker compose -f docker-compose.prod.yml up -d

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 30

# Check service health
echo -e "${YELLOW}Checking service health...${NC}"
services=("nginx" "simstudio" "realtime" "db")
for service in "${services[@]}"; do
    if docker compose -f docker-compose.prod.yml ps | grep -q "$service.*Up"; then
        echo -e "${GREEN}✅ $service is running${NC}"
    else
        echo -e "${RED}❌ $service is not running${NC}"
    fi
done

# Display deployment information
echo ""
echo -e "${GREEN}🎉 Deployment completed!${NC}"
echo ""
echo "Your application should be accessible at:"
echo -e "${GREEN}• Main App: https://sim.codingape.in${NC}"
echo -e "${GREEN}• Realtime: https://realtime.codingape.in${NC}"
echo -e "${GREEN}• Ollama: https://ollama.codingape.in${NC}"
echo ""
echo -e "${YELLOW}⚠️  Important next steps:${NC}"
echo "1. Update your DNS records to point to this server:"
echo "   - sim.codingape.in → $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
echo "   - realtime.codingape.in → $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
echo "   - ollama.codingape.in → $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
echo ""
echo "2. Get real SSL certificates with Let's Encrypt:"
echo "   docker compose -f docker-compose.prod.yml exec nginx ./setup-ssl.sh"
echo ""
echo "3. Monitor logs:"
echo "   docker compose -f docker-compose.prod.yml logs -f"
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"