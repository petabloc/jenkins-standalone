# Jenkins Standalone

Self-contained Jenkins installation with all dependencies included. Runs as non-root user in secure environments.

## Features

- **Self-contained**: Includes OpenJDK 21, Jenkins 2.516.1 LTS, and configurable plugins
- **Non-root execution**: Runs without elevated privileges
- **Portable**: All files contained within installation directory
- **Air-gapped ready**: No runtime internet dependencies
- **Version managed**: Automated security updates and vulnerability scanning

## Quick Start

### From Release

```bash
tar -xzf jenkins-standalone-*.tar.gz
cd jenkins-standalone-*
./bin/jenkins start
```

Jenkins available at http://localhost:8080

### From Source

```bash
git clone https://github.com/petabloc/jenkins-standalone.git
cd jenkins-standalone
./build.sh
```

## Commands

```bash
./bin/jenkins start    # Start Jenkins
./bin/jenkins stop     # Stop Jenkins  
./bin/jenkins restart  # Restart Jenkins
./bin/jenkins status   # Show status
./bin/jenkins logs     # Show logs
```

## Directory Structure

```
jenkins-standalone/
├── bin/jenkins          # Control script
├── lib/                 # OpenJDK and Jenkins WAR
├── jenkins_home/        # Jenkins data and config
├── logs/               # Application logs
├── scripts/            # Management scripts
├── plugins.txt         # Plugin configuration
└── versions.yml        # Version definitions
```

## Configuration

### Default Settings
- **Port**: 8080
- **Jenkins Home**: `./jenkins_home`
- **Security**: Disabled (enable for production)

### Plugins

Edit `plugins.txt` to configure plugins:
```
git:5.0.0
workflow-aggregator:590.v6a_d052e5a_a_b_5
# maven-plugin:3.21
```

Rebuild or use `./scripts/install-plugins.sh` to apply changes.

## Version Management

All versions defined in `versions.yml`:

```yaml
jenkins:
  version: "2.516.1"
jdk:
  version: "21.0.1"
plugins:
  git:
    version: "5.0.0"
```

### Security Updates

```bash
# Check for updates
./scripts/update-versions.sh --dry-run --security-only

# Scan for vulnerabilities
./scripts/security-scan.sh

# Apply security updates
./scripts/update-versions.sh --auto-approve --security-only
```

## Automation

GitHub Actions provide:
- Daily security monitoring
- Automated vulnerability alerts
- Auto-PR for critical security updates
- Weekly comprehensive reports

## System Requirements

- Linux x86_64
- 2GB RAM minimum
- 1GB disk space
- Network access during build only

## Security

Default installation has security disabled for development use.

For production:
1. Enable security in `jenkins_home/config.xml`
2. Configure authentication and authorization
3. Use HTTPS reverse proxy
4. Apply regular security updates

Air-gapped environments use pre-built packages with all security updates included.

## Troubleshooting

**Jenkins won't start:**
```bash
./lib/jdk/bin/java -version  # Check Java
cat logs/jenkins.log          # Check logs
```

**Port conflict:**
Edit `bin/jenkins` to change `--httpPort=8080`

**Permissions:**
```bash
chmod -R u+rw jenkins-standalone/
```

## Components

- **OpenJDK 21.0.1**: Java runtime
- **Jenkins 2.516.1 LTS**: Automation server  
- **Management Scripts**: Version control, security scanning, plugin management

## License

MIT License. Individual components retain respective licenses.