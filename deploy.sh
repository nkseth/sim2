#!/bin/bash

# Simple deployment script for SimStudio
set -e

echo "🚀 Starting SimStudio deployment..."

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Install with: curl -fsSL https://get.docker.com | sh"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose not found. Install with: sudo apt install docker-compose-plugin"
    exit 1
fi

# Create .env if it doesn't exist
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file..."
    cat > .env << 'EOF'
# Database
DATABASE_URL="postgresql://postgres:postgres@db:5432/simstudio"
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=simstudio

# App URLs
BETTER_AUTH_URL=http://sim.codingape.in
NEXT_PUBLIC_APP_URL=http://sim.codingape.in

# Generated secrets - CHANGE THESE!
BETTER_AUTH_SECRET=your_secret_key_here
ENCRYPTION_KEY=your_encryption_key_here
INTERNAL_API_SECRET=your_internal_secret_here

# Services
SOCKET_SERVER_URL=http://realtime.codingape.in
NEXT_PUBLIC_SOCKET_URL=http://realtime.codingape.in

# Optional
COPILOT_API_KEY=
SIM_AGENT_API_URL=
EOF
    
    echo "⚠️  IMPORTANT: Update the secrets in .env file!"
    echo "   Generate with: openssl rand -hex 32"
fi

# Pull and start
echo "📦 Pulling images..."
docker compose -f docker-compose.prod.yml pull

echo "🚀 Starting services..."
docker compose -f docker-compose.prod.yml up -d

# Wait and check
sleep 15
echo "📋 Service status:"
docker compose -f docker-compose.prod.yml ps

echo ""
echo "✅ Deployment complete!"
echo "🌐 Access your app at: http://sim.codingape.in"
echo "🔧 Manage with: ./manage.sh [start|stop|status|logs]"