# OpenClaw EC2 Docker Troubleshooting Guide

## Common Issues and Solutions

### 1. Docker Installation Issues

#### Issue: "Cannot connect to the Docker daemon"
```bash
# Solution: Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Check service status
sudo systemctl status docker

# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

#### Issue: Permission denied when running Docker commands
```bash
# Solution: Fix permissions
sudo chmod 666 /var/run/docker.sock
# OR (better) add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### 2. OpenClaw Container Issues

#### Issue: Container won't start
```bash
# Check logs
docker logs openclaw

# Common causes:
# 1. Port already in use
sudo netstat -tulpn | grep :8080

# 2. Volume permissions
sudo chmod -R 755 ~/openclaw  # For bind mounts

# 3. Insufficient memory
docker run --memory="2g" ...  # Increase memory limit
```

#### Issue: Container starts but immediately stops
```bash
# Check exit code
docker ps -a | grep openclaw

# View detailed logs
docker logs --tail 100 openclaw

# Try running interactively
docker run -it --rm openclaw/openclaw:latest /bin/bash
```

#### Issue: Can't access web interface (port 8080)
```bash
# Check if container is running
docker ps | grep openclaw

# Check port mapping
docker port openclaw

# Check AWS Security Group
# Ensure port 8080 is open for your IP
```

### 3. Network Issues

#### Issue: EC2 instance not accessible
```bash
# Check instance state
aws ec2 describe-instances --instance-id your-instance-id

# Check security groups
aws ec2 describe-security-groups --group-ids your-sg-id

# Test connectivity
telnet your-ec2-ip 22  # SSH
telnet your-ec2-ip 8080  # OpenClaw
```

#### Issue: Slow network performance
```bash
# Check instance type (t3.medium minimum)
# Consider upgrading to t3.large or m5.large

# Check network credits (for t3 instances)
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUCreditBalance \
  --dimensions Name=InstanceId,Value=your-instance-id \
  --start-time $(date -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### 4. Resource Issues

#### Issue: Out of memory
```bash
# Check memory usage
docker stats openclaw
free -h

# Solutions:
# 1. Increase EC2 instance size
# 2. Add swap space
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 3. Limit container memory
docker update --memory="2g" openclaw
```

#### Issue: Disk space full
```bash
# Check disk usage
df -h
docker system df

# Cleanup Docker
docker system prune -a
docker volume prune

# Cleanup old logs
sudo journalctl --vacuum-time=7d
```

#### Issue: High CPU usage
```bash
# Identify process
docker stats openclaw
top -p $(docker inspect --format '{{.State.Pid}}' openclaw)

# Limit CPU
docker update --cpus="1.0" openclaw
```

### 5. Data Persistence Issues

#### Issue: Data lost after container restart
```bash
# Check if using volumes
docker inspect openclaw | grep -A5 Mounts

# Verify volume contents
docker run --rm -v openclaw_workspace:/data alpine ls -la /data

# Solutions:
# 1. Use named volumes (not bind mounts)
# 2. Check volume permissions
# 3. Verify backup strategy
```

#### Issue: Permission errors in volumes
```bash
# Fix volume permissions
docker run --rm -v openclaw_workspace:/data alpine chown -R 1000:1000 /data

# Or recreate volume with correct owner
docker volume rm openclaw_workspace
docker volume create openclaw_workspace
```

### 6. Backup & Recovery Issues

#### Issue: GitHub backup fails
```bash
# Check git configuration
docker exec openclaw git config --list

# Check SSH key setup
docker exec openclaw cat ~/.ssh/id_rsa.pub

# Manual backup
docker run --rm -v openclaw_workspace:/data -v $(pwd):/backup alpine tar czf /backup/backup.tar.gz /data
```

#### Issue: Restore from backup fails
```bash
# Stop container
docker stop openclaw

# Restore volume
docker run --rm -v openclaw_workspace:/data -v $(pwd):/backup alpine tar xzf /backup/backup.tar.gz -C /data

# Start container
docker start openclaw
```

### 7. OpenClaw Specific Issues

#### Issue: OpenClaw skills not working
```bash
# Check skill installation
docker exec openclaw ls -la /app/skills/ | head -10

# Check logs for skill errors
docker logs openclaw | grep -i skill

# Common skill issues:
# 1. Missing dependencies
# 2. API keys not configured
# 3. Platform incompatibility
```

#### Issue: Messaging channels not connecting
```bash
# Check channel configuration
docker exec openclaw cat /home/node/.openclaw/config/channels.json 2>/dev/null || echo "No channel config"

# Check network connectivity
docker exec openclaw curl -I https://api.telegram.org
```

#### Issue: Heartbeat/reminders not working
```bash
# Check HEARTBEAT.md file
docker exec openclaw cat /home/node/.openclaw/workspace/HEARTBEAT.md 2>/dev/null || echo "No HEARTBEAT.md"

# Check cron/scheduler
docker exec openclaw crontab -l 2>/dev/null || echo "No cron jobs"
```

### 8. AWS Specific Issues

#### Issue: EC2 instance stopped unexpectedly
```bash
# Check CloudWatch logs
aws cloudwatch describe-alarms --alarm-name-prefix your-instance

# Check instance state
aws ec2 describe-instances --instance-id your-instance-id --query "Reservations[0].Instances[0].State"

# Common causes:
# 1. Exceeded CPU credits (t3 instances)
# 2. Out of memory
# 3. Scheduled maintenance
```

#### Issue: Cost higher than expected
```bash
# Check Cost Explorer
aws ce get-cost-and-usage \
  --time-period Start=2026-04-01,End=2026-04-30 \
  --granularity MONTHLY \
  --metrics "BlendedCost"

# Cost optimization:
# 1. Use Spot Instances for testing
# 2. Auto-stop during off-hours
# 3. Right-size instance type
```

### 9. Performance Optimization

#### Slow response times
```bash
# Check instance metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=your-instance-id \
  --start-time $(date -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Optimization tips:
# 1. Upgrade instance type
# 2. Use EBS optimized instance
# 3. Enable enhanced networking
```

#### High latency
```bash
# Test network latency
ping your-ec2-ip
mtr your-ec2-ip

# Solutions:
# 1. Choose EC2 region closer to you
# 2. Use CloudFront or CDN
# 3. Optimize application code
```

### 10. Security Issues

#### Unauthorized access attempts
```bash
# Check auth logs
docker logs openclaw | grep -i "auth\|login\|failed"

# Check SSH logs
sudo tail -f /var/log/auth.log | grep sshd

# Security measures:
# 1. Restrict security groups to your IP only
# 2. Use SSH keys instead of passwords
# 3. Enable AWS Shield/VPC
```

#### SSL/TLS certificate issues
```bash
# Check certificate
openssl s_client -connect your-ec2-ip:8080 -servername your-ec2-ip

# Solutions:
# 1. Use Let's Encrypt for SSL
# 2. Use AWS Certificate Manager
# 3. Use SSH tunnel instead of exposing port
```

## Diagnostic Commands

### Quick Health Check
```bash
#!/bin/bash
echo "=== OpenClaw EC2 Health Check ==="
echo "Date: $(date)"
echo ""

echo "1. Docker Status:"
docker ps | grep openclaw
echo ""

echo "2. Container Logs (last 10 lines):"
docker logs --tail 10 openclaw 2>/dev/null || echo "Container not running"
echo ""

echo "3. Resource Usage:"
docker stats --no-stream openclaw 2>/dev/null || echo "Container not running"
echo ""

echo "4. Disk Space:"
df -h /
echo ""

echo "5. Memory Usage:"
free -h
echo ""

echo "6. Network Connectivity:"
curl -I http://localhost:8080 2>/dev/null | head -1 || echo "Cannot connect to OpenClaw"
echo ""

echo "=== Health Check Complete ==="
```

### Log Analysis Commands
```bash
# Search for errors in logs
docker logs openclaw 2>&1 | grep -i "error\|fail\|exception"

# Monitor logs in real-time
docker logs -f openclaw

# Export logs to file
docker logs openclaw > openclaw_logs_$(date +%Y%m%d).txt
```

## Emergency Recovery

### Complete System Recovery
```bash
#!/bin/bash
# Emergency recovery script

echo "Starting emergency recovery..."

# 1. Stop everything
docker stop openclaw 2>/dev/null
docker rm openclaw 2>/dev/null

# 2. Backup existing data
BACKUP_DIR="/home/ubuntu/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR
docker run --rm -v openclaw_workspace:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/workspace_backup.tar.gz /data 2>/dev/null || true

# 3. Clean system
docker system prune -a -f
docker volume prune -f

# 4. Fresh start
docker volume create openclaw_workspace
docker volume create openclaw_config
docker pull openclaw/openclaw:latest
docker run -d \
  --name openclaw \
  -p 8080:8080 \
  -v openclaw_workspace:/home/node/.openclaw/workspace \
  -v openclaw_config:/home/node/.openclaw/config \
  openclaw/openclaw:latest

echo "Recovery complete. Backup saved to: $BACKUP_DIR"
```

## Getting Help

### OpenClaw Resources
- Documentation: https://docs.openclaw.ai
- GitHub Issues: https://github.com/openclaw/openclaw/issues
- Community Discord: https://discord.gg/clawd

### AWS Resources
- AWS Support: https://aws.amazon.com/support
- EC2 Documentation: https://docs.aws.amazon.com/ec2
- AWS Forums: https://forums.aws.amazon.com

### Docker Resources
- Docker Documentation: https://docs.docker.com
- Docker Forums: https://forums.docker.com
- Stack Overflow: https://stackoverflow.com/questions/tagged/docker

## Prevention Tips

1. **Regular backups** - Automate with cron jobs
2. **Monitoring** - Set up CloudWatch alarms
3. **Updates** - Keep Docker and OpenClaw updated
4. **Documentation** - Keep configuration documented
5. **Testing** - Test recovery procedures regularly

---

*Last updated: April 2026*  
*For latest updates, check GitHub repository*