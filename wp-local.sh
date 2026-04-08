#!/bin/bash
# version: 1.0.0

set -eo pipefail

# ===== CONFIG & PATHS =====
CONF_FILE="$HOME/.wp-local.conf"
BASE_DIR="${HOME}/wp-sites"
mkdir -p "$BASE_DIR"

# ===== COLORS =====
GREEN="\033[32m"
RED="\033[31m"
BLUE="\033[34m"
CYAN="\033[36m"
YELLOW="\033[33m"
MAGENTA="\033[35m"
RESET="\033[0m"

# ===== UTILS =====
step() { echo -e "${CYAN}→ $1${RESET}"; }
success() { echo -e "${GREEN}✔ $1${RESET}"; }
error() { echo -e "${RED}✖ $1${RESET}"; exit 1; }

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[[:space:]]+/-/g; s/[^a-z0-9\-]//g'
}

# IMPROVED: Uses | as a delimiter to handle passwords with slashes
safe_sed() {
  local CMD=$1
  local FILE=$2
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$CMD" "$FILE"
  else
    sed -i "$CMD" "$FILE"
  fi
}

get_meta() {
  local SITE=$1
  local KEY=$2
  local META_PATH="$BASE_DIR/$SITE/.meta"
  if [ -f "$META_PATH" ]; then
    grep "^$KEY=" "$META_PATH" | cut -d= -f2-
  fi
}

# ===== LOGO & HELP =====
print_logo() {
  echo -e "${MAGENTA}"
  echo "██╗    ██╗██████╗ "
  echo "██║    ██║██╔══██╗"
  echo "██║ █╗ ██║██████╔╝"
  echo "██║███╗██║██╔═══╝ "
  echo "╚███╔███╔╝██║     "
  echo " ╚══╝╚══╝ ╚═╝     "
  echo -e "${RESET}"
  echo -e "${CYAN}WP CLI by Naveen${RESET}"
  echo ""
  echo -e "${BLUE}Commands:${RESET}"
  echo "  new            Create a brand new WordPress site"
  echo "  start          Start the local server on port $PORT"
  echo "  list           List all your local sites"
  echo "  info [name]    Show site URLs and auto-login link"
  echo "  delete [name]  Wipe a site and its database"
  echo "  doctor         Check & fix environment (PHP/MySQL)"
  echo "  db:list        List all databases in MySQL"
  echo "  update         Pull the latest version from GitHub"
  echo ""
}

# ===== SYSTEM HELPERS =====
install_dependency() {
  local CMD=$1
  echo -e "${YELLOW}! $CMD is required but not found.${RESET}"
  read -p "Would you like me to try and install $CMD for you? (y/n): " CHOICE
  if [[ "$CHOICE" =~ ^[Yy]$ ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      step "Installing $CMD via Homebrew..."
      brew install "$CMD"
    else
      step "Installing $CMD via apt..."
      sudo apt update && sudo apt install -y "$CMD"
    fi
  else
    error "Cannot proceed without $CMD."
  fi
}

fix_mysql_auth() {
  echo -e "${MAGENTA}[fix] Attempting to fix MySQL 8.4+ Authentication Plugin...${RESET}"
  read -s -p "Enter current MySQL Root Password: " M_PASS
  echo ""
  MYSQL_PWD="$M_PASS" mysql -h 127.0.0.1 -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '$M_PASS'; FLUSH PRIVILEGES;" 2>/dev/null
  if [ $? -eq 0 ]; then
    success "Authentication fixed!"
  else
    error "Auto-fix failed. Check if MySQL service is running."
  fi
}

mysql_exec() {
  MYSQL_PWD="$DB_ROOT_PASS" mysql -h 127.0.0.1 -u "$DB_ROOT_USER" -e "$1" 2>/dev/null
}

update_tool() {
  echo -e "${BLUE}Checking for updates from GitHub...${RESET}"
  local INSTALL_PATH="/usr/local/bin/wp-local"
  local VERSION_URL="https://raw.githubusercontent.com/naveenkharwar/wp-local/main/version"
  local REPO_URL="https://raw.githubusercontent.com/naveenkharwar/wp-local/main/wp-local.sh"
  local TMP_FILE
  TMP_FILE=$(mktemp /tmp/wp-local-update.XXXXXX)

  local CURRENT_VERSION LATEST_VERSION
  CURRENT_VERSION=$(grep -m1 '^# version:' "$INSTALL_PATH" 2>/dev/null | cut -d: -f2 | tr -d ' ')
  LATEST_VERSION=$(curl -fsSL "$VERSION_URL" 2>/dev/null)

  if [ -n "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    rm -f "$TMP_FILE"
    success "Already up to date (v$CURRENT_VERSION)."
    return
  fi

  if curl -fsSL "$REPO_URL" -o "$TMP_FILE"; then
    chmod +x "$TMP_FILE"
    if sudo mv "$TMP_FILE" "$INSTALL_PATH"; then
      success "wp-local updated successfully${LATEST_VERSION:+ to v$LATEST_VERSION}!"
    else
      rm -f "$TMP_FILE"
      error "Update failed: could not move file to $INSTALL_PATH."
    fi
  else
    rm -f "$TMP_FILE"
    error "Update failed: could not download from GitHub."
  fi
}

# ===== SETUP WIZARD =====
setup_wizard() {
  echo -e "${MAGENTA}[setup] First-Time Setup Wizard${RESET}"
  read -p "MySQL Root Username [root]: " input_user
  DB_ROOT_USER=${input_user:-root}
  read -s -p "MySQL Root Password [root]: " input_pass
  echo ""
  DB_ROOT_PASS=${input_pass:-root}
  read -p "Default Port [9000]: " input_port
  PORT=${input_port:-9000}

  cat <<EOF > "$CONF_FILE"
DB_ROOT_USER="$DB_ROOT_USER"
DB_ROOT_PASS="$DB_ROOT_PASS"
PORT=$PORT
EOF
  chmod 600 "$CONF_FILE"
}

if [ -f "$CONF_FILE" ]; then source "$CONF_FILE"; else setup_wizard; source "$CONF_FILE"; fi

# ===== CORE COMMANDS =====
run_doctor() {
  print_logo
  echo -e "${BLUE}[diag] System Diagnostic...${RESET}\n"
  command -v php &>/dev/null && success "PHP installed" || install_dependency "php"
  if command -v mysql &>/dev/null; then
    if mysql_exec "SELECT 1;" &>/dev/null; then
      success "MySQL connected"
    else
      echo -e "${RED}✖ MySQL connection failed.${RESET}"
      read -p "Try to auto-fix MySQL 8.4+ authentication plugin? (y/n): " FIXIT
      [[ "$FIXIT" =~ ^[Yy]$ ]] && fix_mysql_auth || error "Check credentials in $CONF_FILE"
    fi
  else
    install_dependency "mysql"
  fi
  [ -w "$BASE_DIR" ] && success "Site storage writable" || error "Cannot write to $BASE_DIR"
  echo ""
}

create_site() {
  print_logo
  read -p "Enter Site Name: " RAW_NAME
  SITENAME=$(slugify "$RAW_NAME")
  [ -d "$BASE_DIR/$SITENAME" ] && error "Site '$SITENAME' already exists!"

  read -p "Admin Username: " WP_USER
  read -s -p "Admin Password: " WP_PASS
  echo ""

  [ -z "$WP_USER" ] && error "Admin username cannot be empty."
  [ -z "$WP_PASS" ] && error "Admin password cannot be empty."

  SITE_DIR="$BASE_DIR/$SITENAME"
  DB_NAME="${SITENAME}_db"
  DB_USER="${SITENAME}_user"
  DB_PASS=$(openssl rand -base64 12)

  step "Setting up WordPress files..."
  mkdir -p "$SITE_DIR" && cd "$SITE_DIR"
  curl -fsSL https://wordpress.org/latest.tar.gz | tar -xz --strip-components=1 || {
    rm -rf "$SITE_DIR"
    error "Failed to download or extract WordPress. Check your internet connection."
  }

  step "Provisioning database..."
  mysql_exec "CREATE DATABASE \`$DB_NAME\`; CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS'; GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"

  step "Applying configuration overrides..."
  cp wp-config-sample.php wp-config.php
  
  # Standard DB replacements - using | as separator to handle special chars in passwords
  safe_sed "s|database_name_here|$DB_NAME|" wp-config.php
  safe_sed "s|username_here|$DB_USER|" wp-config.php
  safe_sed "s|password_here|$DB_PASS|" wp-config.php
  
  # Delete existing definitions
  safe_sed "/WP_HOME/d" wp-config.php
  safe_sed "/WP_SITEURL/d" wp-config.php
  
  SITE_URL="http://127.0.0.1:$PORT/$SITENAME"
  safe_sed "/That's all, stop editing/i\\
define('WP_HOME', '$SITE_URL');\\
define('WP_SITEURL', '$SITE_URL');
" wp-config.php

  mkdir -p wp-content/mu-plugins
  cat <<'PHP' > wp-content/mu-plugins/auto-login.php
<?php
add_action('init', function () {
    if (!isset($_GET['auto_login'])) return;
    $users = get_users(['meta_key' => '_auto_login_key', 'meta_value' => $_GET['auto_login'], 'number' => 1]);
    if ($users) { wp_set_auth_cookie($users[0]->ID); wp_redirect(admin_url()); exit; }
});
PHP

  # PHP's built-in server is single-threaded, so loopback HTTP requests (used by
  # Site Health and other checks) will always time out. Disable them to suppress
  # the false REST API warning in the dashboard.
  cat <<'PHP' > wp-content/mu-plugins/disable-loopback.php
<?php
add_filter('site_status_tests', function ($tests) {
    unset($tests['async']['loopback_requests']);
    return $tests;
});
PHP

  step "Finalizing WordPress installation..."
  export WP_INSTALL_TITLE="$RAW_NAME" WP_INSTALL_USER="$WP_USER" WP_INSTALL_PASS="$WP_PASS"
  OUTPUT=$(php <<'PHP'
<?php
define('WP_INSTALLING', true);
require './wp-load.php';
require ABSPATH . 'wp-admin/includes/upgrade.php';
$title = getenv('WP_INSTALL_TITLE');
$user  = getenv('WP_INSTALL_USER');
$pass  = getenv('WP_INSTALL_PASS');
wp_install($title, $user, 'admin@local.test', true, '', $pass);
$key = wp_generate_password(20, false);
update_user_meta(get_user_by('login', $user)->ID, '_auto_login_key', $key);
echo "KEY=$key";
PHP
)
  unset WP_INSTALL_TITLE WP_INSTALL_USER WP_INSTALL_PASS
  KEY=$(echo "$OUTPUT" | grep KEY | cut -d= -f2)
  LOGIN_URL="$SITE_URL/?auto_login=$KEY"

  echo "SITE_URL=$SITE_URL" > "$SITE_DIR/.meta"
  echo "AUTO_LOGIN=$LOGIN_URL" >> "$SITE_DIR/.meta"

  success "WordPress is ready!"
  echo -e "\n${CYAN}[url]${RESET}   $SITE_URL"
  echo -e "${CYAN}[login]${RESET} $LOGIN_URL\n"
}

start_server() {
  print_logo
  local ROUTER="$BASE_DIR/router.php"
  local PHPINI="$BASE_DIR/php.ini"

  [ ! -f "$ROUTER" ] && cat <<'PHP' > "$ROUTER"
<?php
$root = $_SERVER['DOCUMENT_ROOT']; $path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if (file_exists($root.$path) && is_file($root.$path)) return false;
$s = explode('/', ltrim($path, '/'))[0];
if ($s && is_dir($root.'/'.$s)) { $_SERVER['SCRIPT_NAME']="/$s/index.php"; include $root."/$s/index.php"; }
else return false;
PHP

  [ ! -f "$PHPINI" ] && cat <<'INI' > "$PHPINI"
memory_limit = 512M
upload_max_filesize = 128M
post_max_size = 128M
max_execution_time = 300
display_errors = On
INI

  echo -e "${GREEN}Server running on http://127.0.0.1:$PORT${RESET}"
  php -S 127.0.0.1:$PORT -t "$BASE_DIR" -c "$PHPINI" "$ROUTER"
}

list_sites() {
  print_logo
  echo -e "${BLUE}Available Local Sites:${RESET}"
  for d in "$BASE_DIR"/*; do 
    if [ -d "$d" ] && [ -f "$d/wp-config.php" ]; then
        echo " - $(basename "$d")"
    fi
  done
  echo ""
}

show_info() {
  print_logo
  local SITE_INPUT=$2
  local SITENAME=$(slugify "$SITE_INPUT")
  
  if [ -z "$SITENAME" ] || [ ! -d "$BASE_DIR/$SITENAME" ]; then
    error "Usage: wp-local info [site-name]"
  fi

  local URL=$(get_meta "$SITENAME" "SITE_URL")
  local LOGIN=$(get_meta "$SITENAME" "AUTO_LOGIN")

  echo -e "${BLUE}[info] Site Info: $SITENAME${RESET}"
  echo "---------------------------------"
  echo "Path:  $BASE_DIR/$SITENAME"
  echo "URL:   $URL"
  echo "Login: $LOGIN"
  echo "---------------------------------"
}

delete_site() {
  SITENAME=$(slugify "$2")
  [ -z "$SITENAME" ] && error "Usage: wp-local delete [site-name]"
  echo -e "${RED}[warn] Delete site '$SITENAME' and its database?${RESET}"
  read -p "Confirm (y/n): " CONF
  if [[ "$CONF" =~ ^[Yy]$ ]]; then
    rm -rf "$BASE_DIR/$SITENAME"
    mysql_exec "DROP DATABASE IF EXISTS \`${SITENAME}_db\`; DROP USER IF EXISTS '${SITENAME}_user'@'localhost';"
    success "Site '$SITENAME' deleted."
  else
    echo "Deletion aborted."
  fi
}

list_databases() {
  mysql_exec "SHOW DATABASES;"
}

case "$1" in
  new)     create_site ;;
  start)   start_server ;;
  list)    list_sites ;;
  info)    show_info "$@" ;;
  delete)  delete_site "$@" ;;
  doctor)  run_doctor ;;
  db:list) list_databases ;;
  update)  update_tool ;;
  *)       print_logo ;;
esac