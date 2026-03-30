#!/bin/bash

# ── Load config ──────────────────────────────────────────
source "$(dirname "$0")/config/backup.conf"

# ── Colors ───────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── Variables ────────────────────────────────────────────
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
DATE_READABLE=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)
BACKUP_NAME="backup_${HOSTNAME}_${TIMESTAMP}"
START_TIME=$(date +%s)
SUCCESS_COUNT=0
FAIL_COUNT=0

# ── Logging ──────────────────────────────────────────────
log() {
    local level="$1"
    local message="$2"
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$DATE_READABLE] [$level] $message" | tee -a "$LOG_FILE"
}

# ── Slack notification ───────────────────────────────────
notify_slack() {
    local message="$1"
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -s -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\"}" \
            "$SLACK_WEBHOOK_URL"
    fi
}

# ── Print header ─────────────────────────────────────────
print_header() {
    echo ""
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}  Automated Backup — $HOSTNAME${NC}"
    echo -e "${BLUE}  $DATE_READABLE${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo ""
}

# ── Check dependencies ───────────────────────────────────
check_deps() {
    local deps=("tar" "rsync" "du")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log "ERROR" "Required tool not found: $dep"
            echo -e "${RED}[ERROR] Missing dependency: $dep${NC}"
            exit 1
        fi
    done
    log "INFO" "All dependencies found"
}

# ── Create local backup ──────────────────────────────────
create_backup() {
    local source="$1"
    local source_name
    source_name=$(basename "$source")

    # Check source exists
    if [ ! -e "$source" ]; then
        log "WARN" "Source not found, skipping: $source"
        echo -e "${YELLOW}[WARN]  Skipping (not found): $source${NC}"
        ((FAIL_COUNT++))
        return 1
    fi

    local archive_name="${BACKUP_NAME}_${source_name}.tar.gz"
    local archive_path="${LOCAL_BACKUP_DIR}/${archive_name}"

    mkdir -p "$LOCAL_BACKUP_DIR"

    echo -e "${BLUE}[INFO]  Backing up: $source${NC}"
    log "INFO" "Starting backup of $source"

    # Create compressed archive
    if tar -czf "$archive_path" \
        --exclude='*.log' \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='*.tmp' \
        -C "$(dirname "$source")" \
        "$(basename "$source")" 2>/dev/null; then

        # Get size of archive
        local size
        size=$(du -sh "$archive_path" | cut -f1)

        log "OK" "Backup created: $archive_name ($size)"
        echo -e "${GREEN}[OK]    Backed up: $source_name → $archive_name ($size)${NC}"
        ((SUCCESS_COUNT++))
        return 0
    else
        log "ERROR" "Backup FAILED for: $source"
        echo -e "${RED}[ERROR] Backup failed: $source${NC}"
        ((FAIL_COUNT++))
        return 1
    fi
}

# ── Sync to remote server ────────────────────────────────
sync_remote() {
    if [ -z "$REMOTE_HOST" ] || [ -z "$REMOTE_USER" ]; then
        log "INFO" "Remote sync skipped — no remote host configured"
        echo -e "${YELLOW}[SKIP]  Remote sync: not configured${NC}"
        return 0
    fi

    echo -e "${BLUE}[INFO]  Syncing to remote: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}${NC}"
    log "INFO" "Starting remote sync to ${REMOTE_HOST}"

    if rsync -avz --progress \
        --delete \
        -e "ssh -o StrictHostKeyChecking=no" \
        "${LOCAL_BACKUP_DIR}/" \
        "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/" 2>/dev/null; then

        log "OK" "Remote sync completed to ${REMOTE_HOST}"
        echo -e "${GREEN}[OK]    Remote sync complete${NC}"
    else
        log "ERROR" "Remote sync FAILED"
        echo -e "${RED}[ERROR] Remote sync failed${NC}"
    fi
}

# ── Rotate old backups ───────────────────────────────────
rotate_backups() {
    echo -e "${BLUE}[INFO]  Rotating backups — keeping last $KEEP_LAST${NC}"
    log "INFO" "Starting backup rotation (keep: $KEEP_LAST)"

    # Count current backups
    local total
    total=$(find "$LOCAL_BACKUP_DIR" -name "*.tar.gz" 2>/dev/null | wc -l)

    if [ "$total" -le "$KEEP_LAST" ]; then
        log "INFO" "No rotation needed ($total backups, limit: $KEEP_LAST)"
        echo -e "${GREEN}[OK]    No rotation needed ($total backups)${NC}"
        return
    fi

    # Delete oldest backups beyond KEEP_LAST
    local to_delete=$(( total - KEEP_LAST ))
    find "$LOCAL_BACKUP_DIR" -name "*.tar.gz" \
        | sort \
        | head -n "$to_delete" \
        | while read -r old_backup; do
            rm -f "$old_backup"
            log "INFO" "Deleted old backup: $(basename "$old_backup")"
            echo -e "${YELLOW}[DEL]   Removed old backup: $(basename "$old_backup")${NC}"
        done

    echo -e "${GREEN}[OK]    Rotation done. Kept last $KEEP_LAST backups${NC}"
}

# ── Show backup summary ──────────────────────────────────
show_summary() {
    local end_time
    end_time=$(date +%s)
    local duration=$(( end_time - START_TIME ))

    local total_size
    total_size=$(du -sh "$LOCAL_BACKUP_DIR" 2>/dev/null | cut -f1)

    echo ""
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}  BACKUP SUMMARY${NC}"
    echo -e "${BLUE}=======================================${NC}"
    echo -e "  Successful : ${GREEN}$SUCCESS_COUNT${NC}"
    echo -e "  Failed     : ${RED}$FAIL_COUNT${NC}"
    echo -e "  Duration   : ${duration}s"
    echo -e "  Total size : $total_size"
    echo -e "  Location   : $LOCAL_BACKUP_DIR"
    echo -e "${BLUE}=======================================${NC}"

    log "INFO" "Backup complete — Success: $SUCCESS_COUNT, Failed: $FAIL_COUNT, Duration: ${duration}s"

    # Send Slack summary
    if [ "$FAIL_COUNT" -gt 0 ]; then
        notify_slack "BACKUP on $HOSTNAME — $SUCCESS_COUNT succeeded, $FAIL_COUNT FAILED in ${duration}s"
    else
        notify_slack "BACKUP on $HOSTNAME — All $SUCCESS_COUNT backups completed in ${duration}s ($total_size)"
    fi
}

# ── List all backups ─────────────────────────────────────
list_backups() {
    echo ""
    echo -e "${BLUE}Available backups in $LOCAL_BACKUP_DIR:${NC}"
    echo ""
    if [ -z "$(ls -A "$LOCAL_BACKUP_DIR" 2>/dev/null)" ]; then
        echo "  No backups found."
    else
        ls -lh "$LOCAL_BACKUP_DIR"/*.tar.gz 2>/dev/null | \
            awk '{print "  " $9, "→", $5, "(" $6, $7, $8 ")"}'
    fi
    echo ""
}

# ── Main ─────────────────────────────────────────────────
main() {
    case "$1" in
        --list)
            list_backups
            exit 0
            ;;
        --rotate)
            rotate_backups
            exit 0
            ;;
        --help)
            echo "Usage: $0 [--list | --rotate | --help]"
            echo "  (no args)  run full backup"
            echo "  --list     list all backups"
            echo "  --rotate   rotate old backups manually"
            exit 0
            ;;
    esac

    print_header
    check_deps
    log "INFO" "Backup job started on $HOSTNAME"

    # Back up each source
    for source in "${BACKUP_SOURCES[@]}"; do
        create_backup "$source"
    done

    # Sync to remote
    sync_remote

    # Rotate old backups
    rotate_backups

    # Summary
    show_summary
}
