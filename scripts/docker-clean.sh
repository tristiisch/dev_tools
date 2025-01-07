#!/bin/sh

set -eu

KEEP_DAYS=${KEEP_DAYS:-30}
KEEP_HOURS=$((KEEP_DAYS * 24))

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

info() {
    echo "${CYAN}INFO${RESET} $1"
}

warn() {
    echo "${YELLOW}WARNING${RESET} $1"
}

error() {
    echo "${RED}ERROR${RESET} $1"
}

success() {
    echo "${GREEN}SUCCESS${RESET} $1"
}

cleanup_docker() {
    info "Starting Docker cleanup for unused resources older than $KEEP_DAYS days..."

    TOTAL_STEPS=6

    info "1/$TOTAL_STEPS: Pruning build cache (unused layers not accessed in the last $KEEP_DAYS days)..."
    docker buildx prune -f -a --filter "until=${KEEP_HOURS}h"

    info "2/$TOTAL_STEPS: Pruning unused images (created more than $KEEP_DAYS days ago)..."
    docker image prune -f --filter "until=${KEEP_HOURS}h"

    info "3/$TOTAL_STEPS: Pruning unused containers (stopped containers created more than $KEEP_DAYS days ago)..."
    docker container prune -f --filter "until=${KEEP_HOURS}h"

    info "4/$TOTAL_STEPS: Pruning unused networks (not connected to any container for over $KEEP_DAYS days)..."
    docker network prune -f --filter "until=${KEEP_HOURS}h"

    info "5/$TOTAL_STEPS: Pruning unused volumes (all volumes not in use by any container)..."
    docker volume prune -f -a

	info "6/$TOTAL_STEPS: Pruning unused Docker Scout cache (all SBOMs)..."
	docker scout cache prune -f --sboms

    success "Docker cleanup completed successfully!"
}

if ! command -v docker >/dev/null 2>&1; then
    error "Docker is not installed or not in the PATH. Exiting."
    exit 1
fi

warn "This will remove:"
echo "  - unused containers, images, and networks older than $KEEP_DAYS days."
echo "  - unused build cache layers not accessed in the last $KEEP_DAYS days."
echo "  - unused volumes (all volumes not currently used by any container)."
echo "  - docker scout analysis data."
echo
echo "Are you sure you want to proceed? [y/N]"

read -r CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    info "Operation canceled by user."
    exit 0
fi

cleanup_docker
