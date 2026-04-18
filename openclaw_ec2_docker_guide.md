# OpenClaw on AWS EC2 with Docker - Complete Guide

## Overview
Step-by-step guide to install and run OpenClaw in Docker on AWS EC2 instance.

## Prerequisites
- AWS account with EC2 access
- Basic Linux command line knowledge
- Docker installed (or will install)
- GitHub account (optional, for backups)

## Step 1: Launch EC2 Instance

### Recommended Instance Type
- **t3.medium** or **t3.large** (2-4GB RAM minimum)
- **Ubuntu 22.04 LTS** or **Amazon Linux 2023**
- **Storage:** 20GB+ (for Docker images and data)

### Launch Commands
```bash
# Connect to your EC2 instance
ssh -i your-key.pem ubuntu@your-ec2-public-ip

# Update system
sudo apt-get update && sudo apt-get upgrade -y
```

## Step 2: Install Docker

### Ubuntu/Debian
```bash
# Install Docker
sudo apt-get install -y docker.io docker-compose

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group (avoid sudo)
sudo usermod -aG docker $USER
# Log out and back in for group changes
```

### Amazon Linux 2023
```bash
# Install Docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
```

## Step 3: Install OpenClaw

### Pull OpenClaw Docker Image
```bash
# Pull latest OpenClaw image
docker pull openclaw/openclaw:latest

# Verify image
docker images | grep openclaw
```

## Step 4: Configure Data Persistence

### Option A: Docker Volume (Recommended)
```bash
# Create volume for workspace data
docker volume create openclaw_workspace

# Create volume for configuration
docker volume create openclaw_config
```

### Option B: Bind Mount (EC2 Host Directory)
```bash
# Create directories on EC2
mkdir -p ~/openclaw/workspace
mkdir -p ~/openclaw/config

# Set permissions
chmod -R 755 ~/openclaw
```

## Step 5: Run OpenClaw Container

### Basic Run Command
```bash
docker run -d \
  --name openclaw \
  -p 8080:8080 \
  -v openclaw_workspace:/home/node/.openclaw/workspace \
  -v openclaw_config:/home/node/.openclaw/config \
  openclaw/openclaw:latest
```

### With Environment Variables
```bash
docker run -d \
  --name openclaw \
  -p 8080:8080 \
  -e OPENCLAW_AUTH_TOKEN=your_token_here \
  -v openclaw_workspace:/home/node/.openclaw/workspace \
  -v openclaw_config:/home/node/.openclaw/config \
  openclaw/openclaw:latest
```

## Step 6: Configure Security

### AWS Security Groups
1. Open port **8080** for web interface (restrict to your IP)
2. Open port **22** for SSH (restrict to your IP)
3. Consider using AWS VPN or SSH tunnel for security

### Docker Security
```bash
# Run as non-root user
docker run --user 1000:1000 ...

# Set resource limits
docker run --memory="2g" --cpus="1.0" ...

# Read-only root filesystem (except volumes)
docker run --read-only ...
```

## Step 7: Access OpenClaw

### Web Interface
```
http://your-ec2-public-ip:8080
```

### Check Container Status
```bash
# Check if running
docker ps | grep openclaw

# View logs
docker logs openclaw

# Enter container shell
docker exec -it openclaw /bin/bash
```

## Step 8: Backup Strategy

### Backup Workspace to GitHub
```bash
# Inside container or using docker exec
docker exec openclaw git init
docker exec openclaw git remote add origin https://github.com/yourusername/openclaw-backup.git
docker exec openclaw git add .
docker exec openclaw git commit -m "Backup"
docker exec openclaw git push
```

### EC2 Snapshot Backup
```bash
# Create EBS snapshot via AWS Console or CLI
aws ec2 create-snapshot --volume-id vol-12345 --description "OpenClaw backup"
```

## Step 9: Automation & Monitoring

### Docker Compose File
Create `docker-compose.yml`:
```yaml
version: '3.8'
services:
  openclaw:
    image: openclaw/openclaw:latest
    container_name: openclaw
    ports:
      - "8080:8080"
    volumes:
      - openclaw_workspace:/home/node/.openclaw/workspace
      - openclaw_config:/home/node/.openclaw/config
    environment:
      - OPENCLAW_AUTH_TOKEN=${AUTH_TOKEN}
    restart: unless-stopped
    mem_limit: 2g
    cpus: 1.0

volumes:
  openclaw_workspace:
  openclaw_config:
```

### Systemd Service (Auto-start)
Create `/etc/systemd/system/openclaw.service`:
```ini
[Unit]
Description=OpenClaw Docker Container
Requires=docker.service
After=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker start -a openclaw
ExecStop=/usr/bin/docker stop -t 2 openclaw

[Install]
WantedBy=multi-user.target
```

## Step 10: Troubleshooting

### Common Issues

#### Port Already in Use
```bash
# Check what's using port 8080
sudo netstat -tulpn | grep :8080

# Stop conflicting service or change OpenClaw port
docker run -p 9090:8080 ...
```

#### Permission Denied
```bash
# Fix Docker permissions
sudo chmod 666 /var/run/docker.sock
# Or better: add user to docker group
```

#### Out of Memory
```bash
# Check memory usage
docker stats openclaw

# Increase EC2 instance size or add swap
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

#### Container Won't Start
```bash
# Check logs
docker logs openclaw

# Remove and recreate
docker rm openclaw
docker run ... # with correct parameters
```

## Step 11: Maintenance

### Regular Tasks
```bash
# Update OpenClaw image
docker pull openclaw/openclaw:latest
docker stop openclaw
docker rm openclaw
docker run ... # with same volumes

# Clean up old images
docker image prune -a

# Backup volumes
docker run --rm -v openclaw_workspace:/data -v $(pwd):/backup alpine tar czf /backup/workspace-backup.tar.gz /data
```

### Monitoring Commands
```bash
# Resource usage
docker stats openclaw

# Log monitoring
docker logs --tail 50 -f openclaw

# Disk usage
docker system df
```

## Security Best Practices

1. **Use AWS Security Groups** - Restrict access to your IP only
2. **Regular Updates** - Keep Docker and OpenClaw updated
3. **Backup Regularly** - Both GitHub and EBS snapshots
4. **Monitor Logs** - Check for unusual activity
5. **Use Strong Authentication** - For OpenClaw web interface
6. **Consider VPN** - Instead of exposing port 8080 publicly

## Cost Optimization

1. **Use Spot Instances** - For non-critical deployments
2. **Auto-shutdown** - When not in use (night/weekends)
3. **Right-size instance** - Monitor usage and adjust
4. **Cleanup unused resources** - Old snapshots, images

## Next Steps

1. Configure OpenClaw with your preferred channels (Telegram, WhatsApp, etc.)
2. Set up skills and workflows
3. Create backup automation
4. Monitor performance and adjust resources

## Support & Resources

- OpenClaw Documentation: https://docs.openclaw.ai
- OpenClaw GitHub: https://github.com/openclaw/openclaw
- Docker Documentation: https://docs.docker.com
- AWS EC2 Documentation: https://docs.aws.amazon.com/ec2

---

*Last updated: April 2026*  
*Tested on: AWS EC2 with Ubuntu 22.04 and Amazon Linux 2023*