# OpenClaw on AWS EC2 with Docker - Installation Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [EC2 Instance Setup](#ec2-instance-setup)
3. [Docker Installation](#docker-installation)
4. [OpenClaw Deployment](#openclaw-deployment)
5. [Data Persistence](#data-persistence)
6. [Security Configuration](#security-configuration)
7. [Backup Strategy](#backup-strategy)
8. [Maintenance](#maintenance)

## Prerequisites

### AWS Account Requirements
- Active AWS account
- EC2 service access
- Basic understanding of AWS console

### Technical Requirements
- SSH client (OpenSSH, PuTTY, etc.)
- Basic Linux command line knowledge
- Docker fundamentals

### Instance Recommendations
| Use Case | Instance Type | RAM | Storage | Cost Estimate |
|----------|---------------|-----|---------|---------------|
| Personal/Testing | t3.medium | 4GB | 20GB | ~$30/month |
| Small Team | t3.large | 8GB | 50GB | ~$60/month |
| Production | m5.large | 16GB | 100GB | ~$100/month |

## EC2 Instance Setup

### Step 1: Launch Instance with SSM Support
1. Log into AWS Console
2. Navigate to EC2 → Instances → Launch Instance
3. Choose AMI:
   - **Amazon Linux 2023** (recommended, has SSM agent pre-installed)
   - **Ubuntu 22.04 LTS** (install SSM agent separately)
4. Select instance type: **t3.medium** (good balance of cost/performance)
5. Configure storage: **20GB** minimum
6. **IMPORTANT:** Attach IAM role with `AmazonSSMManagedInstanceCore` policy
7. Configure security group:
   - Remove SSH access (not needed with SSM)
   - Custom TCP (port 8080) - Your IP only
8. Launch instance (no key pair needed)

### Step 2: Connect via AWS Systems Manager (SSM)
1. Go to AWS Console → Systems Manager → Session Manager
2. Click "Start session"
3. Select your EC2 instance
4. You'll connect directly in browser terminal as `ssm-user`

### Step 3: Create Dedicated OpenClaw User
```bash
# Create openclaw user
sudo useradd -m -s /bin/bash openclaw

# Set password (optional)
sudo passwd openclaw

# Add to docker and sudo groups
sudo usermod -aG docker openclaw
sudo usermod -aG wheel openclaw  # Amazon Linux
# OR for Ubuntu:
# sudo usermod -aG sudo openclaw

# Switch to openclaw user
sudo su - openclaw

# Verify user
whoami  # Should show: openclaw
id  # Should show docker and wheel/sudo groups
```

### Step 4: Initial Setup as OpenClaw User
```bash
# Update system packages (Amazon Linux 2023)
sudo yum update -y

# Install basic tools
sudo yum install -y curl wget git htop

# For Ubuntu:
# sudo apt-get update && sudo apt-get upgrade -y
# sudo apt-get install -y curl wget git htop
```

## Docker Installation

### Ubuntu/Debian
```bash
# Install Docker
sudo apt-get install -y docker.io docker-compose

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group (avoid sudo)
sudo usermod -aG docker $USER

# Verify installation
docker --version
docker-compose --version
```

### Amazon Linux 2023
```bash
# Install Docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Post-Installation Verification
```bash
# Test Docker installation
docker run hello-world

# Check Docker service status
sudo systemctl status docker
```

## OpenClaw Deployment

### Pull OpenClaw Image
```bash
# Pull correct OpenClaw Docker image
docker pull alpine/openclaw:latest

# Verify image download
docker images | grep openclaw
```

### Data Persistence Setup

#### Option A: Docker Volumes (Recommended)
```bash
# Create volumes for data persistence
docker volume create openclaw_workspace
docker volume create openclaw_config

# Set correct permissions for OpenClaw (user 1000 in container)
docker run --rm \
  -v openclaw_workspace:/data \
  alpine \
  sh -c "chown 1000:1000 /data && chmod 755 /data"

docker run --rm \
  -v openclaw_config:/data \
  alpine \
  sh -c "chown 1000:1000 /data && chmod 755 /data"

# List volumes
docker volume ls
```

#### Option B: Bind Mounts (Host Directories)
```bash
# Create directories on EC2 host
mkdir -p ~/openclaw/workspace
mkdir -p ~/openclaw/config

# Set appropriate permissions
chmod -R 755 ~/openclaw
```

### Run OpenClaw Container

#### Basic Command with Docker Volumes
```bash
# Run container with Docker volumes and user ID mapping
docker run -d \
  --name openclaw \
  -p 8080:8080 \
  --user 1000:1000 \
  -v openclaw_workspace:/home/node/.openclaw/workspace \
  -v openclaw_config:/home/node/.openclaw/config \
  alpine/openclaw:latest
```

### Alternative: Bind Mounts with Host Directories
```bash
# Create directories with correct permissions
mkdir -p ~/openclaw_data/workspace ~/openclaw_data/config
sudo chown -R 1000:1000 ~/openclaw_data
sudo chmod -R 755 ~/openclaw_data

# Run container with bind mounts
docker run -d \
  --name openclaw \
  -p 8080:8080 \
  --user 1000:1000 \
  -v ~/openclaw_data/workspace:/home/node/.openclaw/workspace \
  -v ~/openclaw_data/config:/home/node/.openclaw/config \
  alpine/openclaw:latest
```

#### With Resource Limits
```bash
docker run -d \
  --name openclaw \
  -p 8080:8080 \
  --memory="2g" \
  --cpus="1.0" \
  -v openclaw_workspace:/home/node/.openclaw/workspace \
  -v openclaw_config:/home/node/.openclaw/config \
  openclaw/openclaw:latest
```

#### Using Docker Compose with Permission Fix
Create `docker-compose.yml`:
```yaml
version: '3.8'
services:
  openclaw:
    image: alpine/openclaw:latest
    container_name: openclaw
    user: "1000:1000"  # Match node user in container
    ports:
      - "8080:8080"
    volumes:
      - ./data/workspace:/home/node/.openclaw/workspace
      - ./data/config:/home/node/.openclaw/config
    environment:
      - NODE_ENV=production
    restart: unless-stopped
    mem_limit: 2g
    cpus: 1.0

# No named volumes needed - using bind mounts with correct permissions
```

Then create data directories with correct permissions:
```bash
mkdir -p ./data/workspace ./data/config
sudo chown -R 1000:1000 ./data
sudo chmod -R 755 ./data

docker-compose up -d
```

Then run:
```bash
docker-compose up -d
```

## Verify Installation

### Check Container Status
```bash
# List running containers
docker ps

# Check OpenClaw logs
docker logs openclaw

# Monitor resource usage
docker stats openclaw
```

### Access OpenClaw Web Interface
1. Get your EC2 public IP from AWS Console
2. Open browser: `http://<ec2-public-ip>:8080`
3. Follow OpenClaw setup instructions

### Test Container Shell Access
```bash
# Enter container shell
docker exec -it openclaw /bin/bash

# Check workspace directory
ls -la /home/node/.openclaw/workspace
```

## Security Configuration

### AWS Security Groups
1. **Restrict SSH access** to your IP only
2. **Restrict port 8080** to your IP only (or use VPN)
3. Consider using **AWS VPN** or **SSH tunnel** for secure access

### Docker Security
```bash
# Run container as non-root user
docker run --user 1000:1000 ...

# Set container to read-only (except volumes)
docker run --read-only -v openclaw_workspace:/home/node/.openclaw/workspace ...

# Use security options
docker run --security-opt no-new-privileges ...
```

### Firewall Configuration (UFW)
```bash
# Install UFW
sudo apt-get install -y ufw

# Configure firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 8080/tcp
sudo ufw enable
```

## Backup Strategy

### GitHub Backup (Recommended)
```bash
# Inside container, initialize git
docker exec openclaw bash -c "cd /home/node/.openclaw/workspace && git init"

# Add remote repository
docker exec openclaw bash -c "cd /home/node/.openclaw/workspace && git remote add origin https://github.com/yourusername/openclaw-backup.git"

# Commit and push
docker exec openclaw bash -c "cd /home/node/.openclaw/workspace && git add . && git commit -m 'Backup' && git push -u origin main"
```

### Volume Backup Script
Create `backup_volumes.sh`:
```bash
#!/bin/bash
BACKUP_DIR="/home/ubuntu/openclaw-backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup workspace volume
docker run --rm -v openclaw_workspace:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/workspace_$DATE.tar.gz /data

# Backup config volume
docker run --rm -v openclaw_config:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/config_$DATE.tar.gz /data

echo "Backup completed: $BACKUP_DIR/*_$DATE.tar.gz"
```

### AWS EBS Snapshot
```bash
# Get volume ID
VOLUME_ID=$(aws ec2 describe-instances --instance-id your-instance-id --query "Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId" --output text)

# Create snapshot
aws ec2 create-snapshot --volume-id $VOLUME_ID --description "OpenClaw backup $(date)"
```

## Maintenance

### Regular Updates
```bash
# Update OpenClaw image
docker pull openclaw/openclaw:latest

# Stop and remove old container
docker stop openclaw
docker rm openclaw

# Start new container with same volumes
docker run -d \
  --name openclaw \
  -p 8080:8080 \
  -v openclaw_workspace:/home/node/.openclaw/workspace \
  -v openclaw_config:/home/node/.openclaw/config \
  openclaw/openclaw:latest
```

### Cleanup
```bash
# Remove unused Docker images
docker image prune -a

# Remove stopped containers
docker container prune

# Remove unused volumes
docker volume prune
```

### Monitoring
```bash
# Check container health
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Monitor logs in real-time
docker logs -f openclaw

# Check resource usage
docker stats --no-stream openclaw
```

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

## Next Steps

1. Configure OpenClaw with your preferred messaging channels
2. Set up skills and workflows
3. Implement automated backups
4. Monitor performance and adjust resources

## Support

- OpenClaw Documentation: https://docs.openclaw.ai
- OpenClaw GitHub: https://github.com/openclaw/openclaw
- Docker Documentation: https://docs.docker.com
- AWS EC2 Documentation: https://docs.aws.amazon.com/ec2

---

*Last updated: April 2026*  
*Tested on: AWS EC2 with Ubuntu 22.04 LTS*