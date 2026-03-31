#!/bin/bash
source "$(dirname "$0")/config/backup.conf"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
DATE_READABLE=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)
START_TIME=$(date +%s)
SUCCESS_COUNT=0
FAIL_COUNT=0

mkdir -p "$LOCAL_BACKUP_DIR" "$(dirname "$LOG_FILE")"

log() { echo "[$DATE_READABLE] [$1] $2" | tee -a "$LOG_FILE"; }

create_backup() {
    local source="$1"
    local source_name
    source_name=$(basename "$source")
    local archive="${LOCAL_BACKUP_DIR}/backup_${source_name}_${TIMESTAMP}.tar.gz"

    echo -e "${BLUE}[INFO]  Backing up: $source${NC}"

    if [ ! -e "$source" ]; then
        echo -e "${YELLOW}[WARN]  Not found, skipping: $source${NC}"
        log "WARN" "Source not found: $source"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi

    if tar -czf "$archive" \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='*.log' \
        -C "$(dirname "$source")" \
        "$source_name" 2>/dev/null; then
        local size
        size=$(du -sh "$archive" | cut -f1)
        echo -e "${GREEN}[OK]    Created: $(basename "$archive") ($size)${NC}"
        log "OK" "Backup created: $(basename "$archive") ($size)"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "${RED}[ERROR] Failed: $source${NC}"
        log "ERROR" "Backup failed: $source"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

rotate_backups() {
    local count
    count=$(find "$LOCAL_BACKUP_DIR" -name "*.tar.gz" | wc -l)
    if [ "$count" -le "$KEEP_LAST" ]; then
        echo -e "${GREEN}[OK]    No rotation needed ($count backups)${NC}"
        return
    fi
    local to_delete=$(( count - KEEP_LAST ))
    find "$LOCAL_BACKUP_DIR" -name "*.tar.gz" | sort | head -n "$to_delete" | while read -r old; do
        rm -f "$old"
        echo -e "${YELLOW}[DEL]   Removed: $(basename "$old")${NC}"
        log "INFO" "Deleted: $(basename "$old")"
    done
}

list_backups() {
    echo -e "${BLUE}Backups in $LOCAL_BACKUP_DIR:${NC}"
    local found=0
    while IFS= read -r f; do
        size=$(du -sh "$f" | cut -f1)
        echo -e "  ${GREEN}$(basename "$f")${NC} ($size)"
        found=$((found + 1))
    done < <(find "$LOCAL_BACKUP_DIR" -name "*.tar.gz" 2>/dev/null | sort -r)
    [ "$found" -eq 0 ] && echo "  No backups found."
}

show_summary() {
    local end_time duration total_size
    end_time=$(date +%s)
    duration=$(( end_time - START_TIME ))
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
    log "INFO" "Done — Success:$SUCCESS_COUNT Failed:$FAIL_COUNT Duration:${duration}s"
}

echo ""
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}  Automated Backup — $HOSTNAME${NC}"
echo -e "${BLUE}  $DATE_READABLE${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

if [ "$1" = "--list" ]; then
    list_backups
    exit 0
fi

if [ "$1" = "--rotate" ]; then
    rotate_backups
    exit 0
fi

log "INFO" "Backup started on $HOSTNAME"

for source in "${BACKUP_SOURCES[@]}"; do
    create_backup "$source"
done

rotate_backups
show_summary
