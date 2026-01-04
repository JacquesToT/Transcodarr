#!/bin/bash
#
# Transcodarr Monitor Launcher
# Starts the TUI monitoring application
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check Python 3
check_python() {
    if command -v python3 &> /dev/null; then
        echo "python3"
        return 0
    elif command -v python &> /dev/null; then
        # Check if it's Python 3
        if python --version 2>&1 | grep -q "Python 3"; then
            echo "python"
            return 0
        fi
    fi
    return 1
}

# Install dependencies
install_deps() {
    local python_cmd="$1"

    echo -e "${YELLOW}Installing dependencies...${NC}"

    # Use pip to install requirements
    if command -v pip3 &> /dev/null; then
        pip3 install -q -r "$SCRIPT_DIR/monitor/requirements.txt"
    elif command -v pip &> /dev/null; then
        pip install -q -r "$SCRIPT_DIR/monitor/requirements.txt"
    else
        "$python_cmd" -m pip install -q -r "$SCRIPT_DIR/monitor/requirements.txt"
    fi

    echo -e "${GREEN}Dependencies installed!${NC}"
}

# Check if textual is installed
check_textual() {
    local python_cmd="$1"
    "$python_cmd" -c "import textual" 2>/dev/null
}

main() {
    # Find Python
    PYTHON_CMD=$(check_python)
    if [[ -z "$PYTHON_CMD" ]]; then
        echo -e "${RED}Error: Python 3 is required.${NC}"
        echo ""
        echo "Install Python with:"
        echo "  brew install python3"
        exit 1
    fi

    # Check/install dependencies
    if ! check_textual "$PYTHON_CMD"; then
        install_deps "$PYTHON_CMD"
    fi

    # Run the monitor
    cd "$SCRIPT_DIR"
    "$PYTHON_CMD" -m monitor "$@"
}

main "$@"
