# wp-local

A lightweight CLI for spinning up local WordPress sites — no Docker, no VMs, no overhead.

Built on PHP's built-in web server and a local MySQL instance, `wp-local` gets a fresh WordPress environment running in seconds.

---

## Requirements

- **PHP** 7.4+
- **MySQL** or **MariaDB**
- **curl**
- macOS or Linux

> **WP-CLI** is optional but recommended. The setup wizard will offer to install it automatically.

---

## Installation

```bash
curl -sSL https://raw.githubusercontent.com/naveenkharwar/wp-local/main/install.sh | bash
```

After installation, run the setup wizard automatically on first run, or verify your environment manually:

```bash
wp-local doctor
```

---

## Commands

| Command | Description |
| :--- | :--- |
| `wp-local new` | Create a new WordPress site |
| `wp-local start` | Start the local development server |
| `wp-local list` | List all managed sites |
| `wp-local info <name>` | Show site URL and auto-login link |
| `wp-local delete <name>` | Remove a site and its database |
| `wp-local doctor` | Check PHP, MySQL, WP-CLI, and permissions |
| `wp-local db:list` | List all databases in MySQL |
| `wp-local wp <name> <args>` | Run a WP-CLI command against a site |
| `wp-local update` | Update to the latest version |

---

## Usage

**Create a site**

```bash
wp-local new
```

Prompts for a site name, admin username, and password. The site is available immediately at `http://127.0.0.1:<port>/<name>`. Uses WP-CLI for installation if available, falls back to the built-in PHP installer otherwise.

**Start the server**

```bash
wp-local start
```

Starts a PHP server serving all sites under `~/wp-sites/`. Multiple sites run on the same port, routed by path.

**Auto-login**

Each site gets a unique auto-login URL printed at creation time. Retrieve it anytime:

```bash
wp-local info <name>
```

**Delete a site**

```bash
wp-local delete <name>
```

Removes the site directory and drops the associated database. Prompts for confirmation before proceeding.

**WP-CLI passthrough**

Run any WP-CLI command against a site without needing to `cd` into it or pass `--path` and `--url` manually:

```bash
wp-local wp <name> plugin install woocommerce --activate
wp-local wp <name> user list
wp-local wp <name> search-replace old-domain.com new-domain.com
wp-local wp <name> cache flush
```

**Update**

```bash
wp-local update
```

Compares the installed version against the latest release on GitHub and updates only if a newer version is available.

---

## WP-CLI setup

WP-CLI is installed automatically during the first-run setup wizard if not already present. To install it manually:

```bash
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
```

### PHP 8.4 deprecation warnings

If you see deprecation notices when running WP-CLI, add the following to your shell profile:

```bash
echo 'export WP_CLI_PHP_ARGS="-d error_reporting=8191"' >> ~/.zshrc && source ~/.zshrc
```

This is handled automatically by `wp-local` for all commands run through the tool.

---

## How it works

- Each site lives in `~/wp-sites/<name>/`
- A single PHP router serves all sites on one port, routing by URL path
- Database credentials are auto-generated per site using `openssl`
- An auto-login key is stored in WordPress user meta and validated via a must-use plugin
- The PHP built-in server is single-threaded — loopback requests (used by Site Health) are disabled via a must-use plugin to prevent false REST API warnings
- Global config (DB root credentials, port) is stored in `~/.wp-local.conf` with `600` permissions

---

## Project structure

```
wp-local/
├── wp-local.sh     # Core CLI
├── install.sh      # Installer
├── uninstall.sh    # Uninstaller
├── version         # Current version number
└── .github/
    └── workflows/
        └── shellcheck.yml  # CI linting
```

---

## License

MIT — see [LICENSE](LICENSE)
