#!/bin/bash

# Create SSL certificate directories
mkdir -p /etc/nginx/ssl/sim.codingape.in
mkdir -p /etc/nginx/ssl/realtime.codingape.in  
mkdir -p /etc/nginx/ssl/ollama.codingape.in

# Install certbot if not present
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
fi

# Function to get SSL certificate
get_certificate() {
    local domain=$1
    echo "Getting SSL certificate for $domain..."
    
    certbot certonly \
        --webroot \
        --webroot-path=/var/www/html \
        --email admin@codingape.in \
        --agree-tos \
        --no-eff-email \
        --non-interactive \
        -d $domain
    
    # Copy certificates to nginx ssl directory
    if [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
        cp /etc/letsencrypt/live/$domain/fullchain.pem /etc/nginx/ssl/$domain/
        cp /etc/letsencrypt/live/$domain/privkey.pem /etc/nginx/ssl/$domain/
        echo "SSL certificate for $domain installed successfully"
    else
        echo "Failed to get SSL certificate for $domain"
        # Create self-signed certificate as fallback
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/nginx/ssl/$domain/privkey.pem \
            -out /etc/nginx/ssl/$domain/fullchain.pem \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=$domain"
        echo "Created self-signed certificate for $domain"
    fi
}

# Create webroot directory for certbot
mkdir -p /var/www/html

# Get certificates for all domains
get_certificate "sim.codingape.in"
get_certificate "realtime.codingape.in"
get_certificate "ollama.codingape.in"

# Set up automatic renewal
echo "0 12 * * * root certbot renew --quiet && nginx -s reload" >> /etc/crontab

echo "SSL setup completed!"