#!/bin/bash
#
# Transcodarr Load Balancer
# Round-robin load balancing for rffmpeg transcoding nodes
#
# This daemon watches for transcode completions and rotates hosts
# to ensure work is distributed across all nodes.
#
# Usage:
#   ./load-balancer.sh start     - Start the load balancer daemon
#   ./load-balancer.sh stop      - Stop the daemon
#   ./load-balancer.sh status    - Show daemon status
#   ./load-balancer.sh rotate    - Manually rotate hosts once
#   ./load-balancer.sh show      - Show current host order
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="/tmp/transcodarr-lb.pid"
LOG_FILE="/tmp/transcodarr-lb.log"
JELLYFIN_CONTAINER="${JELLYFIN_CONTAINER:-jellyfin}"

# Check interval in seconds (how often to check for completed transcodes)
CHECK_INTERVAL="${CHECK_INTERVAL:-5}"

# Source library functions
source "$SCRIPT_DIR/lib/jellyfin-setup.sh" 2>/dev/null || true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*" >> "$LOG_FILE"
}

log_info() {
    log "INFO: $*"
}

log_error() {
    log "ERROR: $*"
}

is_synology() {
    [[ -f /etc/synoinfo.conf ]] || [[ -d /volume1 ]]
}

check_docker() {
    if ! command -v docker &>/dev/null; then
        if is_synology; then
            # Try Synology's docker location
            if [[ -x /usr/local/bin/docker ]]; then
                return 0
            fi
        fi
        echo -e "${RED}Error: Docker not found${NC}"
        return 1
    fi
    return 0
}

check_container() {
    if ! sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${JELLYFIN_CONTAINER}$"; then
        echo -e "${RED}Error: Container '$JELLYFIN_CONTAINER' not running${NC}"
        return 1
    fi
    return 0
}

# ============================================================================
# HOST ROTATION FUNCTIONS
# ============================================================================

# Rotate hosts (move first to end)
do_rotate() {
    local container="${1:-$JELLYFIN_CONTAINER}"
    local quiet="${2:-false}"

    # Get all hosts with their weights
    local hosts
    hosts=$(sudo docker exec "$container" rffmpeg status 2>/dev/null | \
        tail -n +2 | \
        awk '{print $1, $3, $4}')  # IP, ID, WEIGHT

    if [[ -z "$hosts" ]]; then
        [[ "$quiet" != "true" ]] && echo "No hosts configured"
        return 1
    fi

    # Count hosts
    local host_count
    host_count=$(echo "$hosts" | wc -l | tr -d ' ')
    if [[ "$host_count" -lt 2 ]]; then
        [[ "$quiet" != "true" ]] && echo "Only one host, nothing to rotate"
        return 2
    fi

    # Sort by ID to get the first host
    local sorted_hosts
    sorted_hosts=$(echo "$hosts" | sort -t' ' -k2 -n)

    # Get the first host
    local first_line
    first_line=$(echo "$sorted_hosts" | head -1)
    local first_ip first_weight
    first_ip=$(echo "$first_line" | awk '{print $1}')
    first_weight=$(echo "$first_line" | awk '{print $3}')

    # Remove and re-add
    sudo docker exec "$container" rffmpeg remove "$first_ip" 2>/dev/null || return 1
    sudo docker exec "$container" rffmpeg add "$first_ip" --weight "$first_weight" 2>/dev/null || return 1

    [[ "$quiet" != "true" ]] && echo "Rotated: $first_ip moved to end of queue"
    log_info "Rotated host $first_ip (weight: $first_weight) to end of queue"
    return 0
}

# Show current host order
show_hosts() {
    local container="${1:-$JELLYFIN_CONTAINER}"

    echo -e "${CYAN}Current rffmpeg host order:${NC}"
    echo ""

    local hosts
    hosts=$(sudo docker exec "$container" rffmpeg status 2>/dev/null)

    if [[ -z "$hosts" ]] || [[ $(echo "$hosts" | wc -l) -lt 2 ]]; then
        echo -e "${YELLOW}No hosts configured${NC}"
        return 1
    fi

    # Parse and display with priority indicator
    local rank=1
    echo "$hosts" | tail -n +2 | sort -t' ' -k3 -n | while read -r line; do
        local ip id weight state
        ip=$(echo "$line" | awk '{print $1}')
        id=$(echo "$line" | awk '{print $3}')
        weight=$(echo "$line" | awk '{print $4}')
        state=$(echo "$line" | awk '{print $5}')

        if [[ $rank -eq 1 ]]; then
            echo -e "  ${GREEN}#$rank${NC} $ip ${DIM}(ID: $id, Weight: $weight, State: $state)${NC} ${GREEN}<-- NEXT${NC}"
        else
            echo -e "  ${DIM}#$rank${NC} $ip ${DIM}(ID: $id, Weight: $weight, State: $state)${NC}"
        fi
        ((rank++))
    done

    echo ""
}

# ============================================================================
# DAEMON FUNCTIONS
# ============================================================================

# Get count of active transcodes
get_active_transcode_count() {
    local container="${1:-$JELLYFIN_CONTAINER}"

    # Count ffmpeg processes in the container
    local count
    count=$(sudo docker exec "$container" pgrep -c ffmpeg 2>/dev/null || echo "0")
    echo "$count"
}

# Track last known transcode count for completion detection
LAST_TRANSCODE_COUNT=0

# Watch for transcode completions and rotate
daemon_loop() {
    log_info "Load balancer daemon started (PID: $$)"
    log_info "Check interval: ${CHECK_INTERVAL}s"

    LAST_TRANSCODE_COUNT=$(get_active_transcode_count)
    log_info "Initial active transcodes: $LAST_TRANSCODE_COUNT"

    while true; do
        sleep "$CHECK_INTERVAL"

        # Get current transcode count
        local current_count
        current_count=$(get_active_transcode_count)

        # Check if a transcode just completed (count decreased)
        if [[ "$current_count" -lt "$LAST_TRANSCODE_COUNT" ]]; then
            local completed=$((LAST_TRANSCODE_COUNT - current_count))
            log_info "Detected $completed transcode(s) completed (was: $LAST_TRANSCODE_COUNT, now: $current_count)"

            # Rotate hosts for each completion
            for ((i=0; i<completed; i++)); do
                if do_rotate "$JELLYFIN_CONTAINER" "true"; then
                    log_info "Host rotation successful"
                else
                    log_error "Host rotation failed"
                fi
            done
        fi

        LAST_TRANSCODE_COUNT="$current_count"
    done
}

start_daemon() {
    # Check prerequisites
    check_docker || exit 1
    check_container || exit 1

    # Check if already running
    if [[ -f "$PID_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            echo -e "${YELLOW}Load balancer already running (PID: $old_pid)${NC}"
            return 1
        else
            rm -f "$PID_FILE"
        fi
    fi

    # Check host count
    local host_count
    host_count=$(sudo docker exec "$JELLYFIN_CONTAINER" rffmpeg status 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
    if [[ "$host_count" -lt 2 ]]; then
        echo -e "${YELLOW}Warning: Only $host_count host(s) configured. Load balancing requires at least 2 hosts.${NC}"
        echo -e "${DIM}Add more nodes with: ./add-node.sh${NC}"
        return 1
    fi

    echo -e "${CYAN}Starting Transcodarr Load Balancer...${NC}"

    # Start daemon in background
    nohup bash -c "$(declare -f log log_info log_error get_active_transcode_count do_rotate daemon_loop); \
        JELLYFIN_CONTAINER='$JELLYFIN_CONTAINER'; \
        CHECK_INTERVAL='$CHECK_INTERVAL'; \
        LOG_FILE='$LOG_FILE'; \
        LAST_TRANSCODE_COUNT=0; \
        daemon_loop" >> "$LOG_FILE" 2>&1 &

    local pid=$!
    echo "$pid" > "$PID_FILE"

    sleep 1

    if kill -0 "$pid" 2>/dev/null; then
        echo -e "${GREEN}Load balancer started successfully${NC}"
        echo -e "  PID: $pid"
        echo -e "  Log: $LOG_FILE"
        echo -e "  Monitoring $host_count hosts"
        echo ""
        show_hosts
    else
        echo -e "${RED}Failed to start load balancer${NC}"
        rm -f "$PID_FILE"
        return 1
    fi
}

stop_daemon() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo -e "${YELLOW}Load balancer is not running${NC}"
        return 1
    fi

    local pid
    pid=$(cat "$PID_FILE")

    if kill -0 "$pid" 2>/dev/null; then
        echo -e "${CYAN}Stopping load balancer (PID: $pid)...${NC}"
        kill "$pid"
        sleep 1

        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${YELLOW}Process still running, sending SIGKILL...${NC}"
            kill -9 "$pid" 2>/dev/null
        fi

        rm -f "$PID_FILE"
        echo -e "${GREEN}Load balancer stopped${NC}"
    else
        echo -e "${YELLOW}Load balancer process not found (stale PID file)${NC}"
        rm -f "$PID_FILE"
    fi
}

show_status() {
    echo -e "${CYAN}Transcodarr Load Balancer Status${NC}"
    echo ""

    # Daemon status
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  Daemon: ${GREEN}Running${NC} (PID: $pid)"
        else
            echo -e "  Daemon: ${RED}Stopped${NC} (stale PID file)"
        fi
    else
        echo -e "  Daemon: ${DIM}Not running${NC}"
    fi

    # Container status
    if check_container 2>/dev/null; then
        echo -e "  Container: ${GREEN}$JELLYFIN_CONTAINER${NC}"
    else
        echo -e "  Container: ${RED}Not found${NC}"
    fi

    # Active transcodes
    local active
    active=$(get_active_transcode_count 2>/dev/null || echo "?")
    echo -e "  Active transcodes: $active"

    echo ""

    # Show hosts
    show_hosts 2>/dev/null || true

    # Show recent log entries
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "${CYAN}Recent log entries:${NC}"
        tail -5 "$LOG_FILE" 2>/dev/null | while read -r line; do
            echo -e "  ${DIM}$line${NC}"
        done
        echo ""
    fi
}

# ============================================================================
# MAIN
# ============================================================================

usage() {
    echo "Transcodarr Load Balancer"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  start    Start the load balancer daemon"
    echo "  stop     Stop the daemon"
    echo "  status   Show daemon and host status"
    echo "  rotate   Manually rotate hosts once"
    echo "  show     Show current host order"
    echo "  logs     Show daemon logs"
    echo ""
    echo "Environment:"
    echo "  JELLYFIN_CONTAINER  Container name (default: jellyfin)"
    echo "  CHECK_INTERVAL      Check interval in seconds (default: 5)"
    echo ""
}

main() {
    local cmd="${1:-status}"

    case "$cmd" in
        start)
            start_daemon
            ;;
        stop)
            stop_daemon
            ;;
        status)
            show_status
            ;;
        rotate)
            check_docker || exit 1
            check_container || exit 1
            do_rotate "$JELLYFIN_CONTAINER" "false"
            ;;
        show)
            check_docker || exit 1
            check_container || exit 1
            show_hosts "$JELLYFIN_CONTAINER"
            ;;
        logs)
            if [[ -f "$LOG_FILE" ]]; then
                tail -50 "$LOG_FILE"
            else
                echo "No log file found"
            fi
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown command: $cmd${NC}"
            echo ""
            usage
            exit 1
            ;;
    esac
}

main "$@"
