<div align="center">
  <img src="https://github.com/user-attachments/assets/16cc16e2-f1e5-4ae8-9b5f-bbea33fa39bd" alt="NovaBackuper Logo" />
</div>

# What is NovaBackuper? [Persian](readme-fa.md)

**NovaBackuper** is a lightweight, opinionated backup assistant focused on **x-ui** panels.  
It generates compressed, timestamped backups of your x-ui database and ships them straight to a **Telegram** chat or a **local folder** – fully automated, with cron integration, optional AES-256 encryption, and a full CLI for scripted deployments.

## Supported Platforms

- [x] **Telegram** (bot token + chat ID)
- [x] **Local Folder** (any writable path on the server)
- [x] **Telegram + Local Folder** (simultaneous delivery)

## Key Features

- **Interactive installer (wizard-style)**  
  Guided setup for:
  - Backup remark/name
  - Backup interval (cron)
  - Backup destination (Telegram / Local / Both)
  - Telegram bot token & chat ID
  - Optional AES-256 encryption

- **Backup Encryption** _(new in v1.4.0)_
  - Optional AES-256 encryption per profile
  - Priority: `7z` (AES-256) → `zip -e` fallback
  - Password is stored securely in the generated script; no manual entry at runtime

- **Multiple Backup Destinations** _(new in v1.4.0)_
  - **Telegram only** – upload the archive to your bot
  - **Local Folder only** – copy the archive to any writable path
  - **Telegram + Local Folder** – do both in a single run

- **x-ui focused backups**
  - Backs up:
    - `/etc/x-ui/x-ui.db`
    - `/etc/x-ui/x-ui.db-wal`
    - `/etc/x-ui/x-ui.db-shm`

- **Automatic scheduling**
  - Creates a dedicated script in `/root/_<remark>_backuper_script.sh`
  - Automatically registers a cron job to run your backup on the interval you choose

- **Real profile editor** _(new in v1.4.0)_

  After selecting a profile you can change individual settings without recreating the whole profile:

  ```
  1) Change Remark
  2) Change Interval
  3) Change Timezone
  4) Change Telegram Settings
  5) Change Backup Destination
  6) Change Encryption Settings
  7) Save
  8) Cancel
  ```

  Cron is updated automatically when the interval or remark changes.

- **Full CLI / Silent mode** _(new in v1.4.0)_

  ```bash
  # Install a new profile non-interactively
  ./nova-backuper.sh --silent --install \
      --remark main \
      --interval 60 \
      --telegram-token XXXXX \
      --telegram-chat-id XXXXX \
      --telegram-topic-id 123 \
      --timezone Asia/Tehran \
      --destination telegram \
      --encrypt yes \
      --password mypassword

  # Edit a single field of an existing profile
  ./nova-backuper.sh --silent --edit main --interval 30

  # Other actions
  ./nova-backuper.sh --silent --remove
  ./nova-backuper.sh --silent --run
  ./nova-backuper.sh --silent --update
  ./nova-backuper.sh --help
  ```

- **Safe & clean file handling**
  - Compressed with `zip` (split-safe if needed) or encrypted with `7z` / `zip -e`
  - Old backup chunks for the same remark are cleaned up before/after each run

- **Human-friendly Telegram reports**
  - Rich HTML caption with:
    - Date, time & timezone
    - Server IP & hostname
    - Backup ID
  - Sent directly to your chosen Telegram chat or topic thread

### Timezone examples

<details>
<summary><b>Click to show common timezone values (IANA names)</b></summary>

These are example timezone strings you can use when NovaBackuper asks for your timezone.

| Region         | Country / City              | Timezone (IANA)                  |
| -------------- | --------------------------- | -------------------------------- |
| Middle East    | Iran                        | `Asia/Tehran`                    |
| Middle East    | Turkey                      | `Europe/Istanbul`                |
| Middle East    | Saudi Arabia                | `Asia/Riyadh`                    |
| Middle East    | United Arab Emirates        | `Asia/Dubai`                     |
| Middle East    | Qatar                       | `Asia/Qatar`                     |
| Middle East    | Iraq                        | `Asia/Baghdad`                   |
| Middle East    | Israel                      | `Asia/Jerusalem`                 |
| Europe         | United Kingdom (London)     | `Europe/London`                  |
| Europe         | Germany (Berlin)            | `Europe/Berlin`                  |
| Europe         | France (Paris)              | `Europe/Paris`                   |
| Europe         | Italy (Rome)                | `Europe/Rome`                    |
| Europe         | Spain (Madrid)              | `Europe/Madrid`                  |
| Europe         | Netherlands (Amsterdam)     | `Europe/Amsterdam`               |
| Europe         | Sweden (Stockholm)          | `Europe/Stockholm`               |
| Europe         | Norway (Oslo)               | `Europe/Oslo`                    |
| Europe         | Russia (Moscow)             | `Europe/Moscow`                  |
| Americas       | USA – East (New York)       | `America/New_York`               |
| Americas       | USA – Central (Chicago)     | `America/Chicago`                |
| Americas       | USA – Mountain (Denver)     | `America/Denver`                 |
| Americas       | USA – West (Los Angeles)    | `America/Los_Angeles`            |
| Americas       | Canada – East (Toronto)     | `America/Toronto`                |
| Americas       | Canada – West (Vancouver)   | `America/Vancouver`              |
| Americas       | Brazil (São Paulo)          | `America/Sao_Paulo`              |
| Americas       | Argentina (Buenos Aires)    | `America/Argentina/Buenos_Aires` |
| Americas       | Mexico (Mexico City)        | `America/Mexico_City`            |
| Asia & Pacific | India (Kolkata)             | `Asia/Kolkata`                   |
| Asia & Pacific | Pakistan (Karachi)          | `Asia/Karachi`                   |
| Asia & Pacific | China (Shanghai)            | `Asia/Shanghai`                  |
| Asia & Pacific | Hong Kong                   | `Asia/Hong_Kong`                 |
| Asia & Pacific | Japan (Tokyo)               | `Asia/Tokyo`                     |
| Asia & Pacific | South Korea (Seoul)         | `Asia/Seoul`                     |
| Asia & Pacific | Singapore                   | `Asia/Singapore`                 |
| Asia & Pacific | Indonesia (Jakarta)         | `Asia/Jakarta`                   |
| Asia & Pacific | Australia (Sydney)          | `Australia/Sydney`               |
| Asia & Pacific | Australia (Perth)           | `Australia/Perth`                |
| Asia & Pacific | New Zealand (Auckland)      | `Pacific/Auckland`               |
| Africa         | Egypt (Cairo)               | `Africa/Cairo`                   |
| Africa         | South Africa (Johannesburg) | `Africa/Johannesburg`            |
| Africa         | Nigeria (Lagos)             | `Africa/Lagos`                   |
| Africa         | Kenya (Nairobi)             | `Africa/Nairobi`                 |

</details>

- **Cross-distro support**
  - Detects package manager (`apt`, `dnf`, `yum`, `pacman`)
  - Installs required tools automatically (`curl`, `zip`, `cron`, etc.)

## Supported Templates

NovaBackuper is intentionally **focused** and minimal:

- [x] **x-ui panel** (SQLite database in `/etc/x-ui`)

## Installation

To install the latest version, run:

```bash
sudo bash -c "$(curl -sL https://github.com/power0matin/NovaBackuper/raw/master/nova-backuper.sh)"
```

This will:

1. Update your system packages (with your distro's package manager)
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
  */5 * * * * /root/_myxui_backuper_script.sh
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

- Force a backup immediately (bypasses the interval gate):

  ```bash
  FORCE_RUN=1 bash /root/_<remark>_backuper_script.sh
  ```

## Changelog

### v1.4.0

- **Backup Encryption** – optional AES-256 per profile via `7z` or `zip -e`
- **Multiple Destinations** – Telegram, Local Folder, or both simultaneously
- **Real Profile Editor** – edit individual settings without recreating a profile; cron auto-updates
- **Silent / CLI Mode** – full `--install`, `--edit`, `--remove`, `--run`, `--update`, `--help` support for scripted/automated deployments

### v1.0.0

- Initial release: interactive wizard, x-ui backup, Telegram delivery, cron scheduling

## 💙 Support the Project

If NovaBackuper is useful to you, a **star (⭐)** on the repo is more than enough.
Thank you for using it!

## 📬 Contact

**Matin Shahabadi (متین شاه‌آبادی / متین شاه آبادی)**

* Website: [matinshahabadi.ir](https://matinshahabadi.ir)
* Email: [me@matinshahabadi.ir](mailto:me@matinshahabadi.ir)
* GitHub: [power0matin](https://github.com/power0matin)
* LinkedIn: [matin-shahabadi](https://www.linkedin.com/in/matin-shahabadi)

🔹 Maintained by [@power0matin](https://github.com/power0matin)

> [!NOTE]  
> NovaBackuper started as a fork of [Backuper](https://github.com/erfjab/Backuper) and evolved into a focused variant for **x-ui + Telegram**.  
> Huge thanks to **@ErfJabs** for the original idea and base implementation.

[![Stargazers over time](https://starchart.cc/power0matin/NovaBackuper.svg?variant=adaptive)](https://starchart.cc/power0matin/NovaBackuper)
