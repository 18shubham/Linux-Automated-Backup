# Linux Automated Backup System

A production-grade bash backup system with compression, rotation, remote sync and Slack alerts.

## Features
- Backs up multiple directories automatically
- Compresses with tar.gz (excludes .git, node_modules, logs)
- Syncs to remote server via rsync over SSH
- Keeps last N backups and auto-deletes old ones
- Slack notifications on success and failure
- Detailed logging with timestamps
- Restore script included
- Runs daily at 2 AM via cron

## Usage
```bash
./backup.sh             # run full backup
./backup.sh --list      # list all backups
./backup.sh --rotate    # manually rotate old backups
./restore.sh            # interactive restore
```

## Configuration
Copy `config/backup.conf.example` to `config/backup.conf` and edit:
- `BACKUP_SOURCES` — directories to back up
- `LOCAL_BACKUP_DIR` — where to store backups
- `REMOTE_HOST` — optional remote server
- `KEEP_LAST` — how many backups to retain

## Technologies
`bash` · `tar` · `rsync` · `cron` · `ssh` · `curl` · `awk` · `find`

## Author
Shubham · [github.com/18shubham](https://github.com/18shubham)
