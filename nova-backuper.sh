#!/usr/bin/env bash

# NovaBackuper - Interactive x-ui backup installer
# Author: @power0matin
# Version: v1.0.0

set -Eeuo pipefail

#######################################
#            Global constants         #
#######################################

readonly PROJECT_NAME="NovaBackuper"
readonly VERSION="v1.0.0"
readonly OWNER="@power0matin"

readonly SCRIPT_SUFFIX="_backuper_script.sh"
readonly TAG="_backuper."
readonly BACKUP_SUFFIX="${TAG}zip"
readonly SPLIT_SIZE="49m"   # per-part size for zip split

#######################################
#           ANSI color codes          #
#######################################

declare -A COLORS=(
  [red]='\033[1;31m'      [pink]='\033[1;35m' 
  [green]='\033[1;92m'    [spring]='\033[38;5;46m'
  [orange]='\033[1;38;5;208m' [cyan]='\033[1;36m'
  [reset]='\033[0m'
)

#######################################
#       Logging & helper functions    #
#######################################

print()   { echo -e "${COLORS[cyan]}$*${COLORS[reset]}"; }
log()     { echo -e "${COLORS[cyan]}[INFO]${COLORS[reset]} $*"; }
warn()    { echo -e "${COLORS[orange]}[WARN]${COLORS[reset]} $*" >&2; }
error()   { echo -e "${COLORS[red]}[ERROR]${COLORS[reset]} $*" >&2; exit 1; }
wrong()   { echo -e "${COLORS[red]}[WRONG]${COLORS[reset]} $*" >&2; }
success() { echo -e "${COLORS[spring]}${COLORS[green]}[SUCCESS]${COLORS[reset]} $*"; }

input()   { read -p "$(echo -e "${COLORS[orange]}▶ $1${COLORS[reset]} ")" "$2"; }
confirm() { read -p "$(echo -e "${COLORS[pink]}Press any key to continue...${COLORS[reset]}")"; }

trap 'error "An unexpected error occurred. Exiting..."' ERR

#######################################
#           System utilities          #
#######################################

check_root() {
  [[ $EUID -eq 0 ]] || error "This script must be run as root"
}

detect_package_manager() {
  if command -v apt-get &>/dev/null; then
    echo "apt"
  elif command -v dnf &>/dev/null; then
    echo "dnf"
  elif command -v yum &>/dev/null; then
    echo "yum"
  elif command -v pacman &>/dev/null; then
    echo "pacman"
  else
    error "Unsupported package manager"
  fi
}

update_os() {
  local package_manager
  package_manager=$(detect_package_manager)
  log "Updating the system using $package_manager..."

  case $package_manager in
    apt)
      apt-get update -y && apt-get upgrade -y || error "Failed to update the system"
      ;;
    dnf|yum)
      $package_manager update -y || error "Failed to update the system"
      ;;
    pacman)
      pacman -Syu --noconfirm || error "Failed to update the system"
      ;;
  esac
  success "System updated successfully"
}

install_dependencies() {
  local package_manager
  package_manager=$(detect_package_manager)
  local packages=("wget" "zip" "cron" "curl")

  log "Installing dependencies: ${packages[*]}..."

  case $package_manager in
    apt)
      apt-get install -y "${packages[@]}" || error "Failed to install dependencies"
      ;;
    dnf|yum)
      $package_manager install -y "${packages[@]}" || error "Failed to install dependencies"
      ;;
    pacman)
      pacman -Sy --noconfirm "${packages[@]}" || error "Failed to install dependencies"
      ;;
  esac
  success "Dependencies installed successfully"
}

#######################################
#             Main menu               #
#######################################

menu() {
  update_os
  install_dependencies

  while true; do
    clear
    print "======== ${PROJECT_NAME} Menu [${VERSION}] ========"
    print ""
    print "1) Install NovaBackuper for x-ui"
    print "2) Remove all NovaBackuper scripts"
    print "3) Run all NovaBackuper backup scripts"
    print "4) Exit"
    print ""
    input "Choose an option:" choice

    case $choice in
      1)
        start_backup
        ;;
      2)
        cleanup_backups
        ;;
      3)
        run_all_backup_scripts
        ;;
      4)
        print "Thank you for using ${PROJECT_NAME} by ${OWNER}. Goodbye!"
        exit 0
        ;;
      *)
        wrong "Invalid option, please select a valid number!"
        ;;
    esac
  done
}

cleanup_backups() {
  print "Removing all NovaBackuper scripts and related backup files..."

  rm -rf /root/*"$SCRIPT_SUFFIX" /root/*"$TAG"* /root/*_backuper.sh

  crontab -l 2>/dev/null | grep -v "$SCRIPT_SUFFIX" | crontab - || true

  success "All NovaBackuper scripts and cron jobs have been removed."
  sleep 1
}

run_all_backup_scripts() {
  if compgen -G "/root/*${SCRIPT_SUFFIX}" > /dev/null; then
    for script in /root/*${SCRIPT_SUFFIX}; do
      log "Running backup script: $script"
      bash "$script"
    done
  else
    warn "No backup scripts found in /root directory"
  fi
  confirm
}

#######################################
#         Interactive wizard          #
#######################################

start_backup() {
  generate_remark
  generate_timer
  check_xui
  telegram_progress
  generate_script
}

generate_remark() {
  clear
  print "[REMARK]\n"
  print "We need a remark for the backup file (e.g., main, panel, prod_xui).\n"

  while true; do
    input "Enter a remark: " REMARK

    if ! [[ "$REMARK" =~ ^[a-zA-Z0-9_]+$ ]]; then
      wrong "Remark must contain only letters, numbers, or underscores."
    elif [ ${#REMARK} -lt 3 ]; then
      wrong "Remark must be at least 3 characters long."
    elif [ -e "/root/_${REMARK}${SCRIPT_SUFFIX}" ]; then
      wrong "File _${REMARK}${SCRIPT_SUFFIX} already exists. Choose a different remark."
    else
      success "Backup remark: $REMARK"
      break
    fi
  done
  sleep 1
}

generate_timer() {
  clear
  print "[TIMER]\n"
  print "Enter a time interval in minutes for sending backups."
  print "For example, '60' means backups will be sent every 60 minutes.\n"

  while true; do
    input "Enter the number of minutes (1-1440): " minutes

    if ! [[ "$minutes" =~ ^[0-9]+$ ]]; then
      wrong "Please enter a valid number."
    elif [ "$minutes" -lt 1 ] || [ "$minutes" -gt 1440 ]; then
      wrong "Number must be between 1 and 1440."
    else
      break
    fi
  done

  if [ "$minutes" -le 59 ]; then
    TIMER="*/$minutes * * * *"
  elif [ "$minutes" -le 1439 ]; then
    hours=$((minutes / 60))
    remaining_minutes=$((minutes % 60))
    if [ "$remaining_minutes" -eq 0 ]; then
      TIMER="0 */$hours * * *"
    else
      TIMER="*/$remaining_minutes */$hours * * *"
    fi
  else
    TIMER="0 0 * * *"
  fi

  success "Cron job set to run every $minutes minutes: $TIMER"
  sleep 1
}

check_xui() {
  clear
  print "[X-UI PATH CHECK]\n"

  local XUI_DB_FOLDER="/etc/x-ui"

  if [ ! -d "$XUI_DB_FOLDER" ]; then
    error "Directory not found: $XUI_DB_FOLDER

Please make sure x-ui is installed and its config directory is /etc/x-ui."
  fi

  if [ ! -f "${XUI_DB_FOLDER}/x-ui.db" ]; then
    error "x-ui.db not found in $XUI_DB_FOLDER. Aborting."
  fi

  success "x-ui directory detected: $XUI_DB_FOLDER"
  XUI_DB_FOLDER_GLOBAL="$XUI_DB_FOLDER"
  sleep 1
}

telegram_progress() {
  clear
  print "[TELEGRAM CONFIG]\n"
  print "To use Telegram, you need to provide a bot token and a chat ID.\n"

  while true; do
    # Get bot token
    while true; do
      input "Enter the bot token: " BOT_TOKEN
      if [[ -z "$BOT_TOKEN" ]]; then
        wrong "Bot token cannot be empty!"
      elif [[ ! "$BOT_TOKEN" =~ ^[0-9]+:[a-zA-Z0-9_-]{35,}$ ]]; then
        wrong "Invalid bot token format!"
      else
        break
      fi
    done

    # Get chat ID
    while true; do
      input "Enter the chat ID: " CHAT_ID
      if [[ -z "$CHAT_ID" ]]; then
        wrong "Chat ID cannot be empty!"
      elif [[ ! "$CHAT_ID" =~ ^-?[0-9]+$ ]]; then
        wrong "Invalid chat ID format!"
      else
        break
      fi
    done

    while true; do
      input "Enter the topic ID (Press Enter to skip): " TOPIC_ID
      if [[ -z "$TOPIC_ID" ]]; then
        success "No topic ID provided. Messages will be sent to the main chat."
        TOPIC_ID=""
        break
      elif [[ ! "$TOPIC_ID" =~ ^[0-9]+$ ]]; then
        wrong "Invalid topic ID format! Must be a number."
      else
        success "Topic ID set: $TOPIC_ID"
        break
      fi
    done

    # Validate bot token and chat ID
    log "Checking Telegram bot..."
    local response
    if [[ -n "$TOPIC_ID" ]]; then
      response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d message_thread_id="$TOPIC_ID" \
        -d text="Hi from ${PROJECT_NAME} (test message)." )
    else
      response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="Hi from ${PROJECT_NAME} (test message)." )
    fi

    if [[ "$response" -ne 200 ]]; then
      wrong "Invalid bot token, chat ID, topic ID, or Telegram API error! (HTTP $response)"
    else
      success "Bot token and chat ID are valid."
      break
    fi
  done

  TELEGRAM_BOT_TOKEN="$BOT_TOKEN"
  TELEGRAM_CHAT_ID="$CHAT_ID"
  TELEGRAM_TOPIC_ID="$TOPIC_ID"

  success "Telegram configuration completed successfully."
  sleep 1
}

#######################################
#           Script generator          #
#######################################

generate_script() {
  clear
  local BACKUP_PATH="/root/_${REMARK}${SCRIPT_SUFFIX}"

  log "Generating backup script: $BACKUP_PATH"

  cat <<EOL > "$BACKUP_PATH"
#!/usr/bin/env bash
set -Eeuo pipefail

# Auto-generated by ${PROJECT_NAME} (${VERSION})
# Remark: ${REMARK}

ip=\$(hostname -I | awk '{print \$1}')
timestamp=\$(date +%m%d-%H%M)

backup_name="/root/\${timestamp}_${REMARK}${BACKUP_SUFFIX}"
base_name="/root/\${timestamp}_${REMARK}${TAG}"

XUI_DB_DIR="${XUI_DB_FOLDER_GLOBAL}"

log()   { echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$*"; }

# Build caption dynamically at runtime
CAPTION=\$(cat <<EOF
<b>🛡 ${PROJECT_NAME} Report</b>

🗓 <b>Date:</b> \$(date '+%Y-%m-%d (%A)')
⏰ <b>Time:</b> \$(date '+%H:%M:%S %:z')
🌍 <b>Timezone:</b> \$(date +%Z)

💻 <b>Server IP:</b> <code>\${ip}</code>
🧩 <b>Hostname:</b> <code>\$(hostname)</code>

📦 <b>Backup ID:</b> <code>\${timestamp}_${REMARK}</code>
📚 <b>Includes:</b> x-ui database (x-ui.db / x-ui.db-wal / x-ui.db-shm)

⚙️ <b>Mode:</b> Automated x-ui backup via Telegram
EOF
)

reply_markup='{"inline_keyboard":[[{"text":"📦 GitHub","url":"https://github.com/power0matin"},{"text":"👨‍💻 Developer","url":"https://t.me/powermatin"}]]}'

# Clean up old backup files (only specific backup files)
cd /root
rm -rf *"${REMARK}${TAG}"* 2>/dev/null || true

# Ensure x-ui database files exist
if [ ! -f "\${XUI_DB_DIR}/x-ui.db" ]; then
  log "x-ui.db not found in \${XUI_DB_DIR}. Aborting."
  exit 1
fi

# Compress files
log "Creating backup archive: \${backup_name}"
if ! zip -9 -r -s ${SPLIT_SIZE} "\$backup_name" \
  "\${XUI_DB_DIR}/x-ui.db" \
  "\${XUI_DB_DIR}/x-ui.db-wal" 2>/dev/null || true \
  "\${XUI_DB_DIR}/x-ui.db-shm" 2>/dev/null || true; then
    log "Failed to compress ${REMARK} files. Please check the server."
    exit 1
fi

# Send backup files to Telegram
if ls \${base_name}* > /dev/null 2>&1; then
  for FILE in \${base_name}*; do
    log "Sending file: \$FILE"

    if [ -n "${TELEGRAM_TOPIC_ID}" ]; then
      response=\$(curl -s -o /tmp/tg_resp.json -w "%{http_code}" \\
        -F "chat_id=${TELEGRAM_CHAT_ID}" \\
        -F "message_thread_id=${TELEGRAM_TOPIC_ID}" \\
        -F "document=@\${FILE}" \\
        --form-string "caption=\${CAPTION}" \\
        -F "parse_mode=HTML" \\
        --form-string "reply_markup=\${reply_markup}" \\
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument")
    else
      response=\$(curl -s -o /tmp/tg_resp.json -w "%{http_code}" \\
        -F "chat_id=${TELEGRAM_CHAT_ID}" \\
        -F "document=@\${FILE}" \\
        --form-string "caption=\${CAPTION}" \\
        -F "parse_mode=HTML" \\
        --form-string "reply_markup=\${reply_markup}" \\
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument")
    fi

    if [[ "\$response" -eq 200 ]]; then
      log "Backup part sent successfully: \$FILE"
    else
      log "Telegram HTTP status: \$response"
      log "Telegram response body:"
      cat /tmp/tg_resp.json
      log "Failed to send ${REMARK} backup part: \$FILE"
      exit 1
    fi
  done
  log "All backup parts sent successfully."
else
  log "Backup file not found: \$backup_name. Please check the server."
  exit 1
fi

# Final cleanup
rm -rf *"${REMARK}${TAG}"* 2>/dev/null || true
EOL

  chmod +x "$BACKUP_PATH"
  success "Backup script created: $BACKUP_PATH"

  log "Running the backup script for the first time..."
  if bash "$BACKUP_PATH"; then
    success "First backup created and sent successfully."

    log "Setting up cron job..."
    if (crontab -l 2>/dev/null; echo "$TIMER $BACKUP_PATH") | crontab -; then
      success "Cron job set up successfully. Backups will run automatically."
    else
      error "Failed to set up cron job. You can set it manually: $TIMER $BACKUP_PATH"
    fi

    success "🎉 ${PROJECT_NAME} is set up and running!"
    success "Backup script location: $BACKUP_PATH"
    success "Cron job: $TIMER"
    success "Owner: ${OWNER}"
    exit 0
  else
    error "Failed to run backup script. Please check the server."
  fi
}

#######################################
#                 main                #
#######################################

main() {
  clear
  print "${PROJECT_NAME} [${VERSION}] by ${OWNER}"
  print ""
  check_root
  menu
}

main
