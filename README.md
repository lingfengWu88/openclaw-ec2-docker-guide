# OpenClaw EC2 Docker Guide

Complete step-by-step guide to deploy OpenClaw on AWS EC2 using Docker.

## Quick Start

1. Launch EC2 instance with SSM support (Amazon Linux 2023 recommended)
2. Connect via AWS Systems Manager Session Manager
3. Create dedicated 'openclaw' user
4. Install Docker
5. Run OpenClaw container with correct permissions
6. Configure security and backups

## Files

- **[INSTALLATION.md](INSTALLATION.md)** - Complete installation guide
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions
- **[docker-compose.yml](docker-compose.yml)** - Docker Compose configuration
- **[backup_script.sh](backup_script.sh)** - Automated backup script

## Features

- ✅ Step-by-step instructions
- ✅ Data persistence with bind mounts (recommended)
- ✅ Security best practices
- ✅ Backup strategies
- ✅ Troubleshooting guide
- ✅ Cost optimization tips
- ✅ SSM Session Manager integration
- ✅ Permission fixes for EACCES errors

## Prerequisites

- AWS EC2 instance
- Docker installed
- Basic Linux knowledge

## Usage

```bash
# Clone this repository
git clone https://github.com/lingfengWu88/openclaw-ec2-docker-guide.git

# Follow INSTALLATION.md
```

## Contributing

Feel free to submit issues or pull requests for improvements.

## License

MIT License - See [LICENSE](LICENSE) file

## Support

- OpenClaw Documentation: https://docs.openclaw.ai
- OpenClaw GitHub: https://github.com/openclaw/openclaw
- AWS EC2 Documentation: https://docs.aws.amazon.com/ec2