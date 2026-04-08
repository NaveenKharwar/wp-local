#!/bin/bash
set -e

# Colors
RED="\033[31m"
GREEN="\033[32m"
RESET="\033[0m"

echo -e "${RED}⚠️  Warning: This will remove wp-local and ALL sites in ~/wp-sites.${RESET}"
read -p "Confirm Uninstall? (y/n): " CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    sudo rm -f /usr/local/bin/wp-local
    rm -f "$HOME/.wp-local.conf"
    rm -rf "$HOME/wp-sites"
    echo -e "\n${GREEN}✔ Uninstalled successfully.${RESET}"
else
    echo "Aborted."
fi