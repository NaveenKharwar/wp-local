# wp-local

A lightweight CLI for spinning up local WordPress sites — no Docker, no VMs, no overhead.

Built on PHP's built-in web server and a local MySQL instance, `wp-local` gets a fresh WordPress environment running in seconds.

---

## Requirements

- **PHP** 7.4+
- **MySQL** or **MariaDB**
- **curl**
- macOS or Linux

---

## Installation

```bash
curl -sSL https://raw.githubusercontent.com/naveenkharwar/wp-local/main/install.sh | bash
```

After installation, run the doctor command to verify your environment:

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
| `wp-local doctor` | Check PHP, MySQL, and permissions |
| `wp-local db:list` | List all databases in MySQL |
| `wp-local update` | Update to the latest version |

---

## Usage

**Create a site**

```bash
wp-local new
```

You will be prompted for a site name, admin username, and password. The site is available immediately at `http://127.0.0.1:<port>/<name>`.

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

**Update**

```bash
wp-local update
```

Checks the current version against the latest release and updates if a newer version is available.

---

## How it works

- Each site lives in `~/wp-sites/<name>/`
- A single PHP router serves all sites on one port, routing by URL path
- Database credentials are auto-generated per site using `openssl`
- An auto-login key is stored in WordPress user meta and validated via a must-use plugin
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
