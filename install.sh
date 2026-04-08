#!/bin/bash
set -e

REPO_RAW_URL="https://raw.githubusercontent.com/naveenkharwar/wp-local/main/wp-local.sh"
INSTALL_PATH="/usr/local/bin/wp-local"

# Colors
GREEN="\033[32m"
BLUE="\033[34m"
RED="\033[31m"
RESET="\033[0m"

echo -e "${BLUE}Starting wp-local installation...${RESET}"

if ! command -v curl &> /dev/null; then
    echo -e "${RED}✖ Error: curl is not installed.${RESET}"
    exit 1
fi

echo "→ Downloading wp-local..."
curl -sSL "$REPO_RAW_URL" -o wp-local-temp

echo "→ Moving to $INSTALL_PATH (requires sudo)..."
sudo mv wp-local-temp "$INSTALL_PATH"
sudo chmod +x "$INSTALL_PATH"

echo -e "\n${GREEN}✔ Installation complete!${RESET}"
echo -e "Run ${BLUE}wp-local doctor${RESET} to check your environment."