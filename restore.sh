#!/bin/bash

source "$(dirname "$0")/config/backup.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

list_backups() {
    echo ""
    echo -e "${BLUE}Available backups:${NC}"
    echo ""
    local i=1
    while IFS= read -r file; do
        local size
        size=$(du -sh "$file" | cut -f1)
        echo "  [$i] $(basename "$file") ($size)"
        ((i++))
    done < <(find "$LOCAL_BACKUP_DIR" -name "*.tar.gz" | sort -r)
    echo ""
}

restore_backup() {
    local archive="$1"
    local dest="$2"

    if [ ! -f "$archive" ]; then
        echo -e "${RED}[ERROR] Archive not found: $archive${NC}"
        exit 1
    fi

    mkdir -p "$dest"
    echo -e "${BLUE}[INFO]  Restoring: $(basename "$archive") → $dest${NC}"

    if tar -xzf "$archive" -C "$dest"; then
        echo -e "${GREEN}[OK]    Restored successfully to: $dest${NC}"
    else
        echo -e "${RED}[ERROR] Restore failed${NC}"
        exit 1
    fi
}

main() {
    list_backups

    echo -e "${BLUE}Enter backup archive path to restore:${NC}"
    read -r archive

    echo -e "${BLUE}Enter destination directory:${NC}"
    read -r destination

    restore_backup "$archive" "$destination"
}


