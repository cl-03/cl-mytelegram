#!/bin/bash
# run-live-tests.sh - Run live Telegram integration tests
#
# Usage:
#   ./run-live-tests.sh                    # Run all live tests
#   ./run-live-tests.sh test-name          # Run specific test
#   ./run-live-tests.sh --help             # Show help
#
# Prerequisites:
#   Set environment variables or create .env file:
#   - TELEGRAM_API_ID
#   - TELEGRAM_API_HASH
#   - TELEGRAM_TEST_PHONE

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load .env if exists
if [ -f ".env" ]; then
    echo "Loading environment from .env..."
    export $(grep -v '^#' .env | xargs)
fi

# Check required environment variables
check_env() {
    local missing=()

    if [ -z "$TELEGRAM_API_ID" ]; then
        missing+=("TELEGRAM_API_ID")
    fi

    if [ -z "$TELEGRAM_API_HASH" ]; then
        missing+=("TELEGRAM_API_HASH")
    fi

    if [ -z "$TELEGRAM_TEST_PHONE" ]; then
        missing+=("TELEGRAM_TEST_PHONE")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        echo "Missing required environment variables:"
        for var in "${missing[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Create a .env file or export these variables:"
        echo "  export TELEGRAM_API_ID=your_api_id"
        echo "  export TELEGRAM_API_HASH=your_api_hash"
        echo "  export TELEGRAM_TEST_PHONE=+1234567890"
        echo ""
        echo "Get API credentials from: https://my.telegram.org/apps"
        exit 1
    fi
}

# Show help
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "Usage: $0 [test-name]"
    echo ""
    echo "Run live Telegram integration tests."
    echo ""
    echo "Arguments:"
    echo "  test-name    Optional: Run specific test (default: run all)"
    echo ""
    echo "Environment Variables:"
    echo "  TELEGRAM_API_ID       Your API ID from my.telegram.org"
    echo "  TELEGRAM_API_HASH     Your API hash"
    echo "  TELEGRAM_TEST_PHONE   Test phone number (e.g., +1234567890)"
    echo "  TELEGRAM_TEST_CODE    Verification code (default: 12345)"
    echo "  TELEGRAM_TEST_DC      DC ID to use (default: 2)"
    echo ""
    echo "Examples:"
    echo "  $0                              # Run all live tests"
    echo "  $0 test-connect-to-dc1          # Run specific test"
    echo ""
    exit 0
fi

# Check environment
check_env

echo "=== Live Telegram Tests ==="
echo "API ID: $TELEGRAM_API_ID"
echo "API Hash: ${TELEGRAM_API_HASH:0:3}..."
echo "Phone: $TELEGRAM_TEST_PHONE"
echo "DC: ${TELEGRAM_TEST_DC:-2}"
echo ""

# Run SBCL with tests
run_sbcl() {
    sbcl --noinform --noprint <<EOF
(require :asdf)
(asdf:initialize-source-registry '(:source-registry (tree "$SCRIPT_DIR")))
(asdf:load-system :cl-telegram/tests)

(in-package :cl-telegram/tests)

$(if [ -n "$1" ]; then
    echo "(run-single-live-test '$1)"
else
    echo "(run-live-tests)"
fi)

(quit)
EOF
}

# Run tests
if [ -n "$1" ]; then
    echo "Running test: $1"
    run_sbcl "$1"
else
    echo "Running all live tests..."
    run_sbcl
fi

echo ""
echo "Tests completed."
