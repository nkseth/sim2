# 🚀 SimStudio Linux Deployment Checklist

## Pre-Deployment Requirements ✅

### System Requirements
- [ ] Linux server (Ubuntu 20.04+ / CentOS 8+ / Debian 11+)
- [ ] Minimum 4GB RAM, 2 CPU cores
- [ ] 20GB free disk space
- [ ] Root or sudo access

### Network Requirements
- [ ] Server has public IP address
- [ ] Ports 22 (SSH), 80 (HTTP), 443 (HTTPS) accessible
- [ ] Domain `codingape.in` pointed to server IP
- [ ] DNS A records configured:
  - `sim.codingape.in` → Server IP
  - `realtime.codingape.in` → Server IP  
  - `ollama.codingape.in` → Server IP

## Installation Steps 🔧

### 1. Install Docker (if not installed)
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose plugin
sudo apt install docker-compose-plugin

# Logout and login again, then test
docker --version
docker compose version
```

### 2. Clone Repository
```bash
# Clone the repository
git clone https://github.com/nkseth/sim2.git
cd sim2
```

### 3. Run Linux Deployment Script
```bash
# Make executable and run
chmod +x deploy-linux.sh
./deploy-linux.sh
```

## Deployment Verification ✅

### Service Health Checks
```bash
# Check all services
./manage.sh status

# Expected output:
# ✅ nginx is running
# ✅ simstudio is running  
# ✅ realtime is running
# ✅ db is running
```

### Connectivity Tests
```bash
# Test local HTTP access
curl -I http://localhost

# Test specific service ports
curl -I http://localhost:3000  # SimStudio
curl -I http://localhost:3002  # Realtime

# Check listening ports
sudo netstat -tlnp | grep -E ':(80|443|3000|3002|5432)'
```

### DNS Verification
```bash
# Test DNS resolution
nslookup sim.codingape.in
ping sim.codingape.in

# Should resolve to your server IP
```

## Post-Deployment Configuration 🔧

### 1. SSL Certificates (After DNS Propagation)
```bash
# Get Let's Encrypt certificates
./manage.sh ssl

# This will:
# - Get real SSL certificates for all domains
# - Update Nginx configuration
# - Enable HTTPS redirects
```

### 2. Environment Customization
```bash
# Edit environment variables
nano .env

# Important variables to customize:
# - RESEND_API_KEY (for email functionality)
# - COPILOT_API_KEY (for AI features)
# - Database passwords (for production)
```

### 3. Firewall Configuration
```bash
# Ubuntu/Debian (UFW)
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

## Monitoring & Maintenance 📊

### Daily Operations
```bash
# View logs
./manage.sh logs -f

# Check service status
./manage.sh status

# Restart services if needed
./manage.sh restart

# Update to latest version
./manage.sh update
```

### Database Management
```bash
# Backup database
./manage.sh backup

# Restore from backup
./manage.sh restore backup_YYYYMMDD_HHMMSS.sql
```

### Log Management
```bash
# View nginx logs
docker compose -f docker-compose.prod.yml logs nginx

# View application logs
docker compose -f docker-compose.prod.yml logs simstudio

# View all logs with timestamps
docker compose -f docker-compose.prod.yml logs -t --tail=100
```

## Troubleshooting 🔍

### Common Issues

#### 1. Services Won't Start
```bash
# Check logs
docker compose -f docker-compose.prod.yml logs

# Check disk space
df -h

# Check memory usage
free -h

# Restart Docker daemon
sudo systemctl restart docker
```

#### 2. Domain Not Accessible
```bash
# Verify DNS propagation
nslookup sim.codingape.in
dig sim.codingape.in

# Check firewall
sudo ufw status
sudo iptables -L

# Test local access
curl -I http://localhost
```

#### 3. SSL Certificate Issues
```bash
# Check certificate status
openssl x509 -in nginx/ssl/sim.codingape.in/fullchain.pem -text -noout

# Force certificate renewal
docker compose -f docker-compose.prod.yml run --rm certbot renew --force-renewal

# Reload nginx
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

#### 4. Database Connection Issues
```bash
# Check database status
docker compose -f docker-compose.prod.yml exec db pg_isready -U postgres

# Connect to database
docker compose -f docker-compose.prod.yml exec db psql -U postgres -d simstudio

# Check database logs
docker compose -f docker-compose.prod.yml logs db
```

## Security Best Practices 🔒

### 1. Environment Variables
- [ ] Generate strong secrets using `openssl rand -hex 32`
- [ ] Never commit `.env` to version control
- [ ] Rotate secrets regularly

### 2. Database Security
- [ ] Change default PostgreSQL password
- [ ] Enable database SSL connections
- [ ] Regular backups with encryption

### 3. Network Security
- [ ] Configure firewall properly
- [ ] Use fail2ban for SSH protection
- [ ] Enable automatic security updates

### 4. SSL/TLS
- [ ] Use strong SSL ciphers
- [ ] Enable HSTS headers
- [ ] Set up certificate auto-renewal

## Performance Optimization 🚀

### 1. Resource Allocation
```yaml
# In docker-compose.prod.yml, add resource limits
deploy:
  resources:
    limits:
      memory: 2G
      cpus: '1.0'
    reservations:
      memory: 1G
      cpus: '0.5'
```

### 2. Database Tuning
```bash
# Optimize PostgreSQL settings
docker compose -f docker-compose.prod.yml exec db psql -U postgres -c "
  ALTER SYSTEM SET shared_buffers = '256MB';
  ALTER SYSTEM SET effective_cache_size = '1GB';
  SELECT pg_reload_conf();
"
```

### 3. Nginx Optimization
- [ ] Enable gzip compression
- [ ] Set up browser caching
- [ ] Optimize worker processes

## Backup Strategy 💾

### Automated Backups
```bash
# Create backup script
cat > /usr/local/bin/simstudio-backup.sh << 'EOF'
#!/bin/bash
cd /path/to/sim2
./manage.sh backup
find . -name "backup_*.sql" -mtime +7 -delete
EOF

# Make executable
chmod +x /usr/local/bin/simstudio-backup.sh

# Add to crontab (daily backup at 2 AM)
echo "0 2 * * * /usr/local/bin/simstudio-backup.sh" | sudo crontab -
```

## Support & Resources 📚

### Useful Commands
```bash
# Complete system info
./manage.sh status
docker compose -f docker-compose.prod.yml ps
docker stats --no-stream

# Resource usage
df -h
free -h
top -c
```

### Log Locations
- Application logs: `docker compose logs simstudio`
- Nginx logs: `docker compose logs nginx`
- Database logs: `docker compose logs db`
- System logs: `/var/log/syslog`

### Configuration Files
- Environment: `.env`
- Nginx: `nginx/simple-nginx.conf` or `nginx/nginx.conf`
- Docker Compose: `docker-compose.prod.yml`
- SSL Certificates: `nginx/ssl/*/`