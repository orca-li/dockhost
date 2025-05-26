# Multi-Service Docker Hosting Template

This project is a lightweight framework to manage multiple self-hosted services using Docker, Caddy, and Makefile automation.

## Start

```bash
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
loginctl terminate-user $USER
```

## Full Lifecycle

### Build and Start Services

```bash
make build SERVICES="nextcloud wordpress" DOMAIN=mydomain.com
make up
```

- `SERVICES`: List of services to include (must match filenames in templates/env/)
- `DOMAIN`: Root domain for service subdomains (e.g., cloud.mydomain.com, blog.mydomain.com)
- `EMAIL` (optional): Email for Let's Encrypt certificates (default: no-reply@<DOMAIN>)

### Stop All Services

```bash
make down
```

### Safe Cleanup

Remove unused Docker containers, networks, and images (but keep volumes and backups):

```bash
make prune
```

### Full Cleanup

Stop and remove everything (containers, volumes, networks, and images). Make a backup first:

```bash
make force-clean
```

## Backup and Restore
### Backup Volumes

Save all Docker volumes to compressed archives in ./backup/:

```
make backup
```

### Restore Volumes

Restore all volumes from backup archives in ./backup/:

```bash
make restore
```

### Archive Backups

To compress the `backup/` folder into a single file:

```bash
make tar
```

This creates backup.tar.gz.
Extract Archived Backups

To extract from backup.tar.gz back into the backup/ folder:

```bash
make untar
```

This prepares the backup for make restore.

## Add a New Service

Generate template files:

```bash
make template NAME=ghost
```

This creates:
```
    templates/env/ghost.env
    templates/caddy/ghost.caddy
    templates/compose/ghost.yml
```

Edit the files to define your service. Then rebuild and start it:

```bash
make build SERVICES="nextcloud wordpress ghost"
make up
```

## Remove a Service

Stop and remove a service and its templates:

```bash
make remove NAME=ghost
```

This will:

    - Stop the service container
    - Delete the service templates
    - Rebuild the config without the service

# Project Structure

```
.
├── Makefile                  # Automation entry point
├── backup/                  # Compressed volume backups
├── build/                   # Generated configs (Caddyfile, Compose, .env)
├── templates/
│   ├── env/                 # Per-service environment files
│   ├── caddy/               # Per-service Caddy rules
│   └── compose/             # Per-service Docker Compose configs
├── Caddyfile.header         # Global Caddy config
├── docker-compose.header.yml # Global Docker Compose base
```

# Requirements

    Docker and Docker Compose
    GNU Make
    uuidgen (from util-linux)
    envsubst (from gettext)

# Example Services

These are included or supported by default:

    nextcloud
    gitea
    wordpress
    ghost (user-defined example)

You can define more services easily using make template.