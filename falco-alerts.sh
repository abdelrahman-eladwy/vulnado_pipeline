#!/bin/bash

# Falco Alert Viewer - Pretty print Falco security alerts

echo "=========================================="
echo "  Falco Security Alerts (Real-time)"
echo "=========================================="
echo ""

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Follow Falco logs and colorize by severity
kubectl logs -f -n falco -l app.kubernetes.io/name=falco --since=1m 2>/dev/null | while read -r line; do
    if [[ $line == *"Critical"* ]]; then
        echo -e "${RED}[CRITICAL]${NC} $line"
    elif [[ $line == *"Error"* ]]; then
        echo -e "${RED}[ERROR]${NC} $line"
    elif [[ $line == *"Warning"* ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $line"
    elif [[ $line == *"Notice"* ]]; then
        echo -e "${BLUE}[NOTICE]${NC} $line"
    elif [[ $line == *"Informational"* ]] || [[ $line == *"Info"* ]]; then
        echo -e "${GREEN}[INFO]${NC} $line"
    elif [[ $line == *":"* ]] && [[ ! $line == *"Mon Oct"* ]] && [[ ! $line == *"Loading"* ]]; then
        # Likely an alert without explicit level
        echo -e "${YELLOW}[ALERT]${NC} $line"
    fi
done
