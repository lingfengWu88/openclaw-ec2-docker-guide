#!/bin/bash
# OpenClaw Backup Script for AWS EC2
# Automates backup of Docker volumes to local directory and optionally to S3

set -e  # Exit on error

# Configuration
BACKUP_DIR="/home/ubuntu/openclaw-backups"
S3_BUCKET="your-openclaw-backups"  # Change to your S3 bucket name
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/log/openclaw-backup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "${RED}ERROR: $1${NC}"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "${YELLOW}Checking prerequisites...${NC}"
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        error_exit "Docker is not running"
    fi
    
    # Check if OpenClaw container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q '^openclaw$'; then
        error_exit "OpenClaw container not found"
    fi
    
    # Check if volumes exist
    if ! docker volume ls --format '{{.Name}}' | grep -q '^openclaw_workspace$'; then
        error_exit "openclaw_workspace volume not found"
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    log "${GREEN}Prerequisites check passed${NC}"
}

# Backup Docker volumes
backup_volumes() {
    log "${YELLOW}Starting volume backup...${NC}"
    
    # Backup workspace volume
    log "Backing up openclaw_workspace volume..."
    docker run --rm \
        -v openclaw_workspace:/source \
        -v "$BACKUP_DIR:/backup" \
        alpine \
        tar czf "/backup/openclaw_workspace_${DATE}.tar.gz" -C /source . 2>> "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        WORKSPACE_SIZE=$(du -h "$BACKUP_DIR/openclaw_workspace_${DATE}.tar.gz" | cut -f1)
        log "${GREEN}Workspace backup complete: ${WORKSPACE_SIZE}${NC}"
    else
        error_exit "Failed to backup workspace volume"
    fi
    
    # Backup config volume
    log "Backing up openclaw_config volume..."
    docker run --rm \
        -v openclaw_config:/source \
        -v "$BACKUP_DIR:/backup" \
        alpine \
        tar czf "/backup/openclaw_config_${DATE}.tar.gz" -C /source . 2>> "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        CONFIG_SIZE=$(du -h "$BACKUP_DIR/openclaw_config_${DATE}.tar.gz" | cut -f1)
        log "${GREEN}Config backup complete: ${CONFIG_SIZE}${NC}"
    else
        log "${YELLOW}Config volume backup failed (may not exist)${NC}"
    fi
    
    # Create backup manifest
    cat > "$BACKUP_DIR/backup_manifest_${DATE}.json" << EOF
{
    "backup_date": "$(date -Iseconds)",
    "openclaw_version": "$(docker inspect openclaw --format '{{.Config.Image}}')",
    "files": [
        {
            "name": "openclaw_workspace_${DATE}.tar.gz",
            "size": "$WORKSPACE_SIZE"
        },
        {
            "name": "openclaw_config_${DATE}.tar.gz",
            "size": "$CONFIG_SIZE"
        }
    ],
    "system_info": {
        "docker_version": "$(docker --version | cut -d' ' -f3 | tr -d ',')",
        "hostname": "$(hostname)",
        "ec2_instance_id": "$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo 'not_ec2')"
    }
}
EOF
}

# Backup to S3 (optional)
backup_to_s3() {
    if [ -z "$S3_BUCKET" ] || [ "$S3_BUCKET" = "your-openclaw-backups" ]; then
        log "${YELLOW}S3 backup skipped (bucket not configured)${NC}"
        return 0
    fi
    
    log "${YELLOW}Uploading backups to S3...${NC}"
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log "${YELLOW}AWS CLI not installed, skipping S3 upload${NC}"
        return 0
    fi
    
    # Upload files to S3
    for file in "$BACKUP_DIR"/*_${DATE}.*; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            aws s3 cp "$file" "s3://${S3_BUCKET}/openclaw-backups/${filename}" >> "$LOG_FILE" 2>&1
            if [ $? -eq 0 ]; then
                log "${GREEN}Uploaded to S3: ${filename}${NC}"
            else
                log "${YELLOW}Failed to upload to S3: ${filename}${NC}"
            fi
        fi
    done
}

# Cleanup old backups
cleanup_old_backups() {
    log "${YELLOW}Cleaning up old backups (older than ${RETENTION_DAYS} days)...${NC}"
    
    # Find and delete old backup files
    find "$BACKUP_DIR" -name "openclaw_*.tar.gz" -mtime +$RETENTION_DAYS -delete 2>/dev/null
    find "$BACKUP_DIR" -name "backup_manifest_*.json" -mtime +$RETENTION_DAYS -delete 2>/dev/null
    
    # Count remaining backups
    BACKUP_COUNT=$(find "$BACKUP_DIR" -name "openclaw_*.tar.gz" | wc -l)
    log "${GREEN}Cleanup complete. ${BACKUP_COUNT} backups remaining${NC}"
}

# Backup GitHub repository (if configured)
backup_github() {
    log "${YELLOW}Checking for GitHub backup...${NC}"
    
    # Check if workspace has git repository
    if docker exec openclaw bash -c "cd /home/node/.openclaw/workspace && git status" &> /dev/null; then
        log "Git repository found, creating commit..."
        
        # Commit changes
        docker exec openclaw bash -c "cd /home/node/.openclaw/workspace && \
            git add . && \
            git commit -m 'Auto-backup $(date)' || true" >> "$LOG_FILE" 2>&1
        
        # Push to remote if configured
        if docker exec openclaw bash -c "cd /home/node/.openclaw/workspace && git remote -v" | grep -q "origin"; then
            log "Pushing to GitHub..."
            docker exec openclaw bash -c "cd /home/node/.openclaw/workspace && git push origin main" >> "$LOG_FILE" 2>&1
            if [ $? -eq 0 ]; then
                log "${GREEN}GitHub backup complete${NC}"
            else
                log "${YELLOW}GitHub push failed${NC}"
            fi
        else
            log "${YELLOW}Git remote not configured${NC}"
        fi
    else
        log "${YELLOW}No git repository found in workspace${NC}"
    fi
}

# Create restore instructions
create_restore_instructions() {
    cat > "$BACKUP_DIR/RESTORE_INSTRUCTIONS_${DATE}.txt" << EOF
OpenClaw Backup Restore Instructions
====================================
Backup Date: $(date)
Backup Files:
- openclaw_workspace_${DATE}.tar.gz
- openclaw_config_${DATE}.tar.gz

To restore:

1. Stop OpenClaw container:
   docker stop openclaw
   docker rm openclaw

2. Restore volumes:
   # Restore workspace
   docker run --rm \\
     -v openclaw_workspace:/target \\
     -v ${BACKUP_DIR}:/backup \\
     alpine \\
     tar xzf /backup/openclaw_workspace_${DATE}.tar.gz -C /target
   
   # Restore config (if needed)
   docker run --rm \\
     -v openclaw_config:/target \\
     -v ${BACKUP_DIR}:/backup \\
     alpine \\
     tar xzf /backup/openclaw_config_${DATE}.tar.gz -C /target

3. Start OpenClaw:
   docker-compose up -d
   # OR
   docker run -d \\
     --name openclaw \\
     -p 8080:8080 \\
     -v openclaw_workspace:/home/node/.openclaw/workspace \\
     -v openclaw_config:/home/node/.openclaw/config \\
     openclaw/openclaw:latest

4. Verify:
   docker logs openclaw
   curl http://localhost:8080/health

Notes:
- This backup was created on: $(date)
- EC2 Instance: $(hostname)
- OpenClaw Version: $(docker inspect openclaw --format '{{.Config.Image}}' 2>/dev/null || echo 'unknown')
EOF
}

# Main execution
main() {
    log "${GREEN}=== OpenClaw Backup Started ===${NC}"
    
    # Check prerequisites
    check_prerequisites
    
    # Perform backups
    backup_volumes
    backup_github
    backup_to_s3
    
    # Cleanup and documentation
    cleanup_old_backups
    create_restore_instructions
    
    # Summary
    TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
    log "${GREEN}=== Backup Complete ===${NC}"
    log "Backup location: $BACKUP_DIR"
    log "Total backup size: $TOTAL_SIZE"
    log "Backup files:"
    ls -lh "$BACKUP_DIR"/*_${DATE}.* 2>/dev/null | while read line; do
        log "  $line"
    done
    
    # Exit successfully
    exit 0
}

# Handle script arguments
case "$1" in
    "test")
        echo "Running in test mode..."
        S3_BUCKET=""  # Disable S3 in test mode
        main
        ;;
    "cron")
        # For cron jobs, redirect all output to log file
        exec >> "$LOG_FILE" 2>&1
        main
        ;;
    *)
        main
        ;;
esac