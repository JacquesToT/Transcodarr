#!/bin/bash
#
# Transcodarr Monitor Launcher
# Starts the TUI monitoring application
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

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
        if python --version 2>&1 | grep -q "Python 3"; then
            echo "python"
            return 0
        fi
    fi
    return 1
}

# Setup virtual environment
setup_venv() {
    local python_cmd="$1"

    if [[ ! -d "$VENV_DIR" ]]; then
        echo -e "${YELLOW}Creating virtual environment...${NC}"
        "$python_cmd" -m venv "$VENV_DIR"
    fi

    # Activate venv
    source "$VENV_DIR/bin/activate"

    # Install/update dependencies if needed
    if ! python -c "import textual" 2>/dev/null; then
        echo -e "${YELLOW}Installing dependencies...${NC}"
        pip install -q --upgrade pip
        pip install -q -r "$SCRIPT_DIR/monitor/requirements.txt"
        echo -e "${GREEN}Dependencies installed!${NC}"
    fi
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

    # Setup and activate virtual environment
    setup_venv "$PYTHON_CMD"

    # Run the monitor from the venv
    cd "$SCRIPT_DIR"
    python -m monitor "$@"
}

main "$@"
