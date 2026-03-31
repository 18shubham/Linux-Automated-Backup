# Linux Automated Backup System

Production-grade bash backup system with compression, rotation, remote sync and alerts.

## Features
- Backs up multiple directories automatically
- Compresses with tar.gz (excludes .git, node_modules, logs)
- Keeps last N backups and auto-deletes old ones (rotation)
- Remote sync via rsync over SSH
- Slack notifications on success and failure
- Full logging with timestamps
- Runs daily at 2 AM via cron

## Usage
```bash
./backup.sh           # run full backup
./backup.sh --list    # list all backups
./backup.sh --rotate  # manually rotate old backups
```

## Configuration
Copy `config/backup.conf.example` to `config/backup.conf` and set:
- `BACKUP_SOURCES` — array of directories to back up
- `LOCAL_BACKUP_DIR` — where backups are stored locally
- `KEEP_LAST` — how many backups to retain
- `REMOTE_HOST` — optional remote server for rsync
- `SLACK_WEBHOOK_URL` — optional Slack alerts

## Cron Setup
```bash
# Run daily at 2 AM
0 2 * * * /home/shubham/Linux-Automated-Backup/backup.sh
```

## Technologies
`bash` · `tar` · `rsync` · `cron` · `ssh` · `curl` · `find` · `awk`

## Author
Shubham · [github.com/18shubham](https://github.com/18shubham)
