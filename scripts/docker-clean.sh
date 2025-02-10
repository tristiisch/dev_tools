#!/bin/sh

set -eu

FORCE=false
KEEP_HOURS=24
KEEP="1 day"
ALL_VOLUMES=false

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

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -f, --force       Skip confirmation prompt."
    echo "  --days=N          Set the number of days (default: 30)."
    echo "  --hours=N         Set the number of hours."
    echo "  -h, --help        Show this help message and exit."
    exit 1
}

for arg in "$@"; do
    case "$arg" in
        --force|-f)
            FORCE=true
            ;;
        --hours=*)
            HOURS="${arg#*=}"
            if ! echo "$HOURS" | grep -qE '^[0-9]+$'; then
                error "--hours requires a valid number"
                exit 1
            fi
			KEEP="$HOURS hours"
			KEEP_HOURS="$HOURS"
            ;;
        --days=*)
            DAYS="${arg#*=}"
            if ! echo "$DAYS" | grep -qE '^[0-9]+$'; then
                error "--days requires a valid number"
                exit 1
            fi
			KEEP="$DAYS days"
			KEEP_HOURS=$((DAYS * 24))
            ;;
        --all-volumes=*)
			ALL_VOLUMES=true
            ;;
        -h|--help)
            print_usage
            ;;
        *)
            error "Unknown option: $arg"
            print_usage
            ;;
    esac
    shift
done

cleanup_docker() {
    info "Starting Docker cleanup for unused resources older than $KEEP..."

    TOTAL_STEPS=5
	if docker scout >/dev/null 2>&1; then
		TOTAL_STEPS=$((TOTAL_STEPS + 1))
	fi

    info "1/$TOTAL_STEPS: Pruning build cache (unused layers not accessed in the last $KEEP)..."
    docker buildx prune -f -a --filter "until=${KEEP_HOURS}h"

    info "2/$TOTAL_STEPS: Pruning unused images (created more than $KEEP ago)..."
    docker image prune -f -a --filter "until=${KEEP_HOURS}h"

    info "3/$TOTAL_STEPS: Pruning unused containers (stopped containers created more than $KEEP ago)..."
    docker container prune -f --filter "until=${KEEP_HOURS}h"

    info "4/$TOTAL_STEPS: Pruning unused networks (not connected to any container for over $KEEP)..."
    docker network prune -f --filter "until=${KEEP_HOURS}h"

	if [ "$ALL_VOLUMES" = true ]; then
		info "5/$TOTAL_STEPS: Pruning unused volumes (all volumes not in use by any container)..."
		docker volume prune -f -a
	else
		info "5/$TOTAL_STEPS: Pruning unused anonymous volumes (anonymous volumes not in use by any container)..."
		docker volume prune -f
	fi

	if docker scout >/dev/null 2>&1; then
		info "6/$TOTAL_STEPS: Pruning unused Docker Scout cache (all SBOMs)..."
		docker scout cache prune -f --sboms
	fi

    success "Docker cleanup completed successfully!"
}

if ! command -v docker >/dev/null 2>&1; then
    error "Docker is not installed or not in the PATH. Exiting."
    exit 1
fi

warn "This will remove:"
echo "  - unused containers, images, and networks older than $KEEP."
echo "  - unused build cache layers not accessed in the last $KEEP."
if [ "$ALL_VOLUMES" = true ]; then
	echo "  - unused volumes (all volumes not currently used by any container)."
else
	echo "  - unused anonymous volumes (anonymous volumes not currently used by any container)."
fi
if docker scout >/dev/null 2>&1; then
	echo "  - docker scout analysis data."
fi
echo

if [ "$FORCE" = false ]; then
    echo "Are you sure you want to proceed? [y/N]"
    read -r CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        info "Operation canceled by user."
        exit 0
    fi
fi

cleanup_docker
