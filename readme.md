<div align="center">
  <img src="https://github.com/user-attachments/assets/16cc16e2-f1e5-4ae8-9b5f-bbea33fa39bd" alt="NovaBackuper Logo" />
</div>

# What is NovaBackuper? [Persian](readme-fa.md)

**NovaBackuper** is a lightweight, opinionated backup assistant focused on **x-ui** panels.  
It generates compressed, timestamped backups of your x-ui database and ships them straight to a **Telegram** chat – fully automated, with cron integration.

## Supported Platform

- [x] **Telegram** (bot token + chat ID)

## Key Features

- **Interactive installer (wizard-style)**  
  Guided setup for:

  - Backup remark/name
  - Backup interval (cron)
  - Telegram bot token & chat ID

- **x-ui focused backups**

  - Backs up:
    - `/etc/x-ui/x-ui.db`
    - `/etc/x-ui/x-ui.db-wal`
    - `/etc/x-ui/x-ui.db-shm`

- **Automatic scheduling**

  - Creates a dedicated script in `/root/_<remark>_backuper_script.sh`
  - Automatically registers a cron job to run your backup on the interval you choose

- **Safe & clean file handling**

  - Compressed with `zip` (split-safe if needed)
  - Old backup chunks for the same remark are cleaned up before/after each run

- **Human-friendly Telegram reports**

  - Rich HTML caption with:
    - Date, time & timezone
    - Server IP & hostname
    - Backup ID
  - Sent directly to your chosen Telegram chat

- **Cross-distro support**
  - Detects package manager (`apt`, `dnf`, `yum`, `pacman`)
  - Installs required tools automatically (`curl`, `zip`, `cron`, etc.)

## Supported Templates

NovaBackuper is intentionally **focused** and minimal:

- [x] **x-ui panel** (SQLite database in `/etc/x-ui`)

During the wizard you can also **add or remove custom directories** to include extra paths in the backup archive.

> [!NOTE]  
> NovaBackuper started as a fork of [Backuper](https://github.com/erfjab/Backuper) and evolved into a focused variant for **x-ui + Telegram**.  
> Huge thanks to **@ErfJabs** for the original idea and base implementation.

## Installation

To install the latest version, run:

```bash
sudo bash -c "$(curl -sL https://github.com/power0matin/NovaBackuper/raw/master/nova-backuper.sh)"
```

This will:

1. Update your system packages (with your distro’s package manager)
2. Install required dependencies
3. Launch the interactive **NovaBackuper** wizard
4. Create a backup script in `/root/`
5. Run the first backup immediately
6. Register a cron job to keep backups running automatically

## Usage (Quick Overview)

After running the installer:

- Your generated script will look like:

  ```bash
  /root/_<remark>_backuper_script.sh
  ```

- A cron entry will be created similar to:

  ```cron
  */30 * * * * /root/_myxui_backuper_script.sh
  ```

You can always:

- Edit or remove the cron job with:

  ```bash
  crontab -e
  ```

- Run a backup manually:

  ```bash
  bash /root/_<remark>_backuper_script.sh
  ```

## 💙 Support the Project

If NovaBackuper is useful to you, a **star (⭐)** on the repo is more than enough.
Thank you for using it!

🔹 Maintained by [@power0matin](https://github.com/power0matin)

[![Stargazers over time](https://starchart.cc/power0matin/NovaBackuper.svg?variant=adaptive)](https://starchart.cc/power0matin/NovaBackuper)
