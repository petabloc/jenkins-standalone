# Jenkins Standalone

Self-contained Jenkins installation with OpenJDK 21, Jenkins 2.516.1 LTS, and pre-installed plugins. Runs as daemon without root privileges.

## Quick Start

### From Release

```bash
tar -xzf jenkins-standalone-*.tar.gz
cd jenkins-standalone-*
./bin/jenkins start
```

### From Development Artifact

```bash
unzip jenkins-standalone-package.zip
tar -xzf jenkins-standalone-*.tar.gz
cd jenkins-standalone-*
./bin/jenkins start
```

Jenkins available at http://localhost:8080

**First-time setup:** Use initial admin password from `jenkins_home/secrets/initialAdminPassword`

### From Source

```bash
git clone https://github.com/petabloc/jenkins-standalone.git
cd jenkins-standalone
./build.sh
```

## Commands

```bash
./bin/jenkins start    # Start Jenkins daemon (survives SSH disconnect)
./bin/jenkins stop     # Stop Jenkins daemon
./bin/jenkins restart  # Restart Jenkins
./bin/jenkins status   # Show daemon status
./bin/jenkins logs     # Tail logs (Ctrl+C to exit)
./bin/jenkins config   # Show configuration
```

## Directory Structure

```
jenkins-standalone/
├── bin/jenkins          # Control script
├── conf/               # Configuration files
│   └── jenkins.conf    # Main configuration file
├── lib/                # OpenJDK and Jenkins WAR
├── jenkins_home/       # Jenkins data and config
├── logs/               # Application logs
├── scripts/            # Management scripts
├── plugins.txt         # Plugin configuration
└── versions.yml        # Version definitions
```

## Configuration

Edit `conf/jenkins.conf` to customize settings:

```bash
HTTP_PORT=8080                    # Web interface port
JVM_XMS=512m                      # Initial heap size
JVM_XMX=2g                        # Maximum heap size
JVM_OPTS="-server -Djava.awt.headless=true"
JENKINS_OPTS="--sessionTimeout=0"
BIND_ADDRESS=0.0.0.0              # 0.0.0.0=all interfaces, 127.0.0.1=localhost only
DEVELOPMENT_MODE=false
LOG_LEVEL=INFO
JENKINS_HOME_OVERRIDE=""          # Custom Jenkins home (optional)
```

## Plugins

Edit `plugins.txt` to configure plugins, then rebuild:
```
git:latest
workflow-aggregator:latest
# maven-plugin:latest
```

## Security Updates

```bash
./scripts/update-versions.sh --dry-run --security-only  # Check updates
./scripts/security-scan.sh                               # Scan vulnerabilities  
./scripts/update-versions.sh --auto-approve --security-only  # Apply updates
```

GitHub Actions: Daily security monitoring, vulnerability alerts, auto-PRs for critical updates.

## Requirements

- Linux x86_64, 2GB RAM, 1GB disk
- Network access during build only

## Troubleshooting

```bash
# Jenkins won't start
./lib/jdk/bin/java -version  # Check Java
cat logs/jenkins.log          # Check logs

# Port conflict  
# Edit conf/jenkins.conf to change HTTP_PORT

# Permissions
chmod -R u+rw jenkins-standalone/
```

## Admin Setup

On first launch, Jenkins displays setup wizard requiring initial admin password:

1. Access http://localhost:8080
2. Enter password from `jenkins_home/secrets/initialAdminPassword`  
3. Click "Select plugins to install"
4. Click "None" to skip plugin installation (plugins already pre-installed)
5. Create admin user account
6. Setup completes

## Components

- OpenJDK 21.0.1, Jenkins 2.516.1 LTS, pre-installed plugins
- Version management and security scanning scripts  
- Setup wizard creates admin user on first launch

## License

MIT License